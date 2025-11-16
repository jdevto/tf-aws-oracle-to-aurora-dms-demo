#!/usr/bin/env bash
set -eo pipefail

# Function to validate JSON without triggering error handling
is_valid_json() {
  echo "$1" | jq . >/dev/null 2>&1 || return 1
  return 0
}

if [ -z "${DMS_TASK_ARN:-}" ]; then
  echo "Error: DMS_TASK_ARN environment variable is required"
  exit 1
fi

echo "Starting DMS replication task: $DMS_TASK_ARN"

# Get task details to find replication instance and endpoints
# Query all tasks and filter by ARN (ensure region is set)
ALL_TASKS_OUTPUT=$(aws dms describe-replication-tasks --region ap-southeast-2 --output json 2>&1)

# Check for actual AWS CLI errors (not JSON content with "Error" in field names)
if echo "$ALL_TASKS_OUTPUT" | grep -q "^An error occurred\|^usage:\|Unable to locate credentials"; then
  echo "Error: Failed to query DMS tasks"
  echo "$ALL_TASKS_OUTPUT"
  exit 1
fi

# Validate JSON before parsing
if ! echo "$ALL_TASKS_OUTPUT" | jq empty 2>/dev/null; then
  echo "Error: Invalid JSON response from describe-replication-tasks"
  echo "$ALL_TASKS_OUTPUT"
  exit 1
fi

ALL_TASKS="$ALL_TASKS_OUTPUT"
TASK_DATA=$(echo "$ALL_TASKS" | jq --arg arn "$DMS_TASK_ARN" '.ReplicationTasks[] | select(.ReplicationTaskArn == $arn)')

if [ -z "$TASK_DATA" ] || [ "$TASK_DATA" = "null" ] || [ "$TASK_DATA" = "" ]; then
  echo "Error: Could not find DMS replication task: $DMS_TASK_ARN"
  echo "Available tasks:"
  echo "$ALL_TASKS" | jq -r '.ReplicationTasks[] | "  \(.ReplicationTaskIdentifier): \(.ReplicationTaskArn) [\(.Status)]"'
  exit 1
fi

REPLICATION_INSTANCE_ARN=$(echo "$TASK_DATA" | jq -r '.ReplicationInstanceArn // empty')
SOURCE_ENDPOINT_ARN=$(echo "$TASK_DATA" | jq -r '.SourceEndpointArn // empty')
TARGET_ENDPOINT_ARN=$(echo "$TASK_DATA" | jq -r '.TargetEndpointArn // empty')
TASK_STATUS=$(echo "$TASK_DATA" | jq -r '.Status // empty')

if [ -z "$TASK_STATUS" ]; then
  echo "Error: Could not determine task status"
  exit 1
fi

echo "Task status: $TASK_STATUS"
echo "Replication instance: $REPLICATION_INSTANCE_ARN"

# Check if task is already running
if [ "$TASK_STATUS" = "running" ]; then
  echo "DMS replication task is already running"
  exit 0
fi

# Check connection status if task is in ready state
if [ "$TASK_STATUS" = "ready" ]; then
  echo "Checking connection status..."

  # Get existing connections for this replication instance
  # Always start with empty connections - we'll populate if we get valid data
  CONNECTIONS='{"Connections":[]}'
  SOURCE_STATUS="unknown"
  TARGET_STATUS="unknown"
  SOURCE_FAILURE=""
  TARGET_FAILURE=""

  # Try to get connections, suppress all errors
  CONNECTIONS_OUTPUT=$(aws dms describe-connections \
    --region ap-southeast-2 \
    --filters "Name=replication-instance-arn,Values=$REPLICATION_INSTANCE_ARN" \
    --output json 2>/dev/null) || true

  # Only use if it looks like valid JSON (has Connections key)
  if [ -n "$CONNECTIONS_OUTPUT" ] && echo "$CONNECTIONS_OUTPUT" | grep -q '"Connections"' 2>/dev/null; then
    # Try to extract connection data in subshells to prevent script failure
    SOURCE_CONN_DATA=$( (set +e; echo "$CONNECTIONS_OUTPUT" | jq --arg arn "$SOURCE_ENDPOINT_ARN" '.Connections[]? | select(.EndpointArn == $arn)' 2>/dev/null | head -1) || echo "")
    TARGET_CONN_DATA=$( (set +e; echo "$CONNECTIONS_OUTPUT" | jq --arg arn "$TARGET_ENDPOINT_ARN" '.Connections[]? | select(.EndpointArn == $arn)' 2>/dev/null | head -1) || echo "")

    if [ -n "$SOURCE_CONN_DATA" ] && [ "$SOURCE_CONN_DATA" != "null" ] && [ "$SOURCE_CONN_DATA" != "" ]; then
      SOURCE_STATUS=$( (set +e; echo "$SOURCE_CONN_DATA" | jq -r '.Status // "unknown"' 2>/dev/null) || echo "unknown")
      SOURCE_FAILURE=$( (set +e; echo "$SOURCE_CONN_DATA" | jq -r '.LastFailureMessage // ""' 2>/dev/null) || echo "")
    fi

    if [ -n "$TARGET_CONN_DATA" ] && [ "$TARGET_CONN_DATA" != "null" ] && [ "$TARGET_CONN_DATA" != "" ]; then
      TARGET_STATUS=$( (set +e; echo "$TARGET_CONN_DATA" | jq -r '.Status // "unknown"' 2>/dev/null) || echo "unknown")
      TARGET_FAILURE=$( (set +e; echo "$TARGET_CONN_DATA" | jq -r '.LastFailureMessage // ""' 2>/dev/null) || echo "")
    fi
  fi

  echo "Source connection status: $SOURCE_STATUS"
  if [ -n "$SOURCE_FAILURE" ] && [ "$SOURCE_FAILURE" != "null" ] && [ "$SOURCE_FAILURE" != "" ]; then
    echo "  Source failure message: $SOURCE_FAILURE"
  fi
  echo "Target connection status: $TARGET_STATUS"
  if [ -n "$TARGET_FAILURE" ] && [ "$TARGET_FAILURE" != "null" ] && [ "$TARGET_FAILURE" != "" ]; then
    echo "  Target failure message: $TARGET_FAILURE"
  fi

  # If source connection failed, exit immediately (don't retry)
  if [ "$SOURCE_STATUS" = "failed" ]; then
    echo ""
    echo "Error: Source connection test failed!"
    if [ -n "$SOURCE_FAILURE" ] && [ "$SOURCE_FAILURE" != "null" ] && [ "$SOURCE_FAILURE" != "" ]; then
      echo "Failure message: $SOURCE_FAILURE"
    fi
    echo "Please check:"
    echo "  1. RDS PostgreSQL is running and accessible"
    echo "  2. Security groups allow DMS to connect to RDS (port 5432)"
    echo "  3. Database credentials are correct"
    echo ""
    echo "You may need to fix the connection issue and manually test the connection in the AWS console."
    exit 1
  fi

  # If target connection failed, exit immediately (don't retry)
  if [ "$TARGET_STATUS" = "failed" ]; then
    echo ""
    echo "Error: Target connection test failed!"
    if [ -n "$TARGET_FAILURE" ] && [ "$TARGET_FAILURE" != "null" ] && [ "$TARGET_FAILURE" != "" ]; then
      echo "Failure message: $TARGET_FAILURE"
    fi
    echo "Please check:"
    echo "  1. Aurora cluster is running and accessible"
    echo "  2. Security groups allow DMS to connect to Aurora (port 5432)"
    echo "  3. Database credentials are correct"
    echo ""
    echo "You may need to fix the connection issue and manually test the connection in the AWS console."
    exit 1
  fi

  # If connections are not successful, try to test them
  if [ "$SOURCE_STATUS" != "successful" ] || [ "$TARGET_STATUS" != "successful" ]; then
    echo "Initiating connection tests..."

    # Try to test source connection (may fail if already testing)
    aws dms test-connection \
      --region ap-southeast-2 \
      --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
      --endpoint-arn "$SOURCE_ENDPOINT_ARN" > /dev/null 2>&1 || true

    # Try to test target connection (may fail if already testing)
    aws dms test-connection \
      --region ap-southeast-2 \
      --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
      --endpoint-arn "$TARGET_ENDPOINT_ARN" > /dev/null 2>&1 || true

    # Wait for connections to become successful (check every 5 seconds, max 2 minutes)
    echo "Waiting for connection tests to complete..."
    set +e
    set +o pipefail
    for i in {1..24}; do
      CONNECTIONS_OUTPUT=$(aws dms describe-connections \
        --region ap-southeast-2 \
        --filters "Name=replication-instance-arn,Values=$REPLICATION_INSTANCE_ARN" \
        --output json 2>&1)

      # Validate JSON before parsing
      if echo "$CONNECTIONS_OUTPUT" | grep -q "^An error occurred\|^usage:"; then
        echo "  Warning: Failed to query connections, retrying..."
        sleep 5
        continue
      else
        CONNECTIONS="$CONNECTIONS_OUTPUT"
      fi

      SOURCE_STATUS=$(echo "$CONNECTIONS" | jq -r --arg arn "$SOURCE_ENDPOINT_ARN" '.Connections[]? | select(.EndpointArn == $arn) | .Status // "testing"' 2>/dev/null | head -1 || echo "testing")
      TARGET_STATUS=$(echo "$CONNECTIONS" | jq -r --arg arn "$TARGET_ENDPOINT_ARN" '.Connections[]? | select(.EndpointArn == $arn) | .Status // "testing"' 2>/dev/null | head -1 || echo "testing")

      # Default to "testing" if status is empty
      SOURCE_STATUS=${SOURCE_STATUS:-testing}
      TARGET_STATUS=${TARGET_STATUS:-testing}

      if [ "$SOURCE_STATUS" = "successful" ] && [ "$TARGET_STATUS" = "successful" ]; then
        echo "Connection tests successful!"
        break
      fi

      if [ "$SOURCE_STATUS" = "failed" ] || [ "$TARGET_STATUS" = "failed" ]; then
        echo ""
        echo "Error: Connection test failed. Source: $SOURCE_STATUS, Target: $TARGET_STATUS"

        # Get failure messages
        SOURCE_FAIL_MSG=$( (set +e; echo "$CONNECTIONS" | jq -r --arg arn "$SOURCE_ENDPOINT_ARN" '.Connections[]? | select(.EndpointArn == $arn) | .LastFailureMessage // ""' 2>/dev/null) || echo "")
        TARGET_FAIL_MSG=$( (set +e; echo "$CONNECTIONS" | jq -r --arg arn "$TARGET_ENDPOINT_ARN" '.Connections[]? | select(.EndpointArn == $arn) | .LastFailureMessage // ""' 2>/dev/null) || echo "")

        if [ -n "$SOURCE_FAIL_MSG" ] && [ "$SOURCE_FAIL_MSG" != "null" ] && [ "$SOURCE_FAIL_MSG" != "" ]; then
          echo "Source failure message: $SOURCE_FAIL_MSG"
        fi
        if [ -n "$TARGET_FAIL_MSG" ] && [ "$TARGET_FAIL_MSG" != "null" ] && [ "$TARGET_FAIL_MSG" != "" ]; then
          echo "Target failure message: $TARGET_FAIL_MSG"
        fi

        echo "Please check your database endpoints and security groups."
        exit 1
      fi

      if [ $i -lt 24 ]; then
        echo "  Waiting... (attempt $i/24) - Source: $SOURCE_STATUS, Target: $TARGET_STATUS"
        sleep 5
      fi
    done
    set -o pipefail
    set -e

    # Final check
    if [ "$SOURCE_STATUS" != "successful" ] || [ "$TARGET_STATUS" != "successful" ]; then
      echo ""
      echo "Error: Connection tests did not complete successfully after 2 minutes."
      echo "Source: $SOURCE_STATUS, Target: $TARGET_STATUS"
      echo "Please check your database endpoints and security groups, then try again."
      exit 1
    fi
  else
    echo "Connections are already successful!"
  fi
fi

# Try to start the task
echo "Starting DMS replication task..."
if aws dms start-replication-task \
  --region ap-southeast-2 \
  --replication-task-arn "$DMS_TASK_ARN" \
  --start-replication-task-type start-replication 2>&1; then
  echo "DMS replication task started successfully"
  exit 0
else
  EXIT_CODE=$?
  echo ""
  echo "Failed to start DMS replication task."
  echo ""
  echo "Common issues:"
  echo "  1. Connection tests must be successful - wait a few minutes and try again"
  echo "  2. The task is already running"
  echo "  3. The task is in a state that cannot be started"
  echo ""
  echo "To check task status, run:"
  echo "  aws dms describe-replication-tasks --filters Name=replication-task-arn,Values=$DMS_TASK_ARN --query 'ReplicationTasks[0].{Status:Status,StopReason:StopReason}' --output table"
  exit $EXIT_CODE
fi
