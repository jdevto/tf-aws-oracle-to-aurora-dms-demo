#!/usr/bin/env bash
set -euo pipefail

if [ -z "${DMS_TASK_ARN:-}" ]; then
  echo "Error: DMS_TASK_ARN environment variable is required"
  exit 1
fi

aws dms start-replication-task \
  --replication-task-arn "$DMS_TASK_ARN" \
  --start-replication-task-type start-replication

echo "DMS replication task started successfully"
