# RDS PostgreSQL to Aurora PostgreSQL DMS Migration

Terraform infrastructure for migrating RDS PostgreSQL database to Aurora PostgreSQL using AWS DMS with full load + CDC capabilities.

## Overview

This solution provisions:

- VPC with private subnets in ap-southeast-2
- **Source**: RDS PostgreSQL instance (db.t4g.small) with logical replication enabled
- **Target**: Aurora PostgreSQL cluster (db.t4g.medium)
- AWS DMS replication instance and endpoints
- Security groups configured for RDS, Aurora, and DMS communication
- CloudWatch log groups for database monitoring

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- PostgreSQL client (psql) installed locally (for schema application)
- jq installed (for Makefile targets)

## Configuration

All configuration is in `infra/locals.tf`. Key settings:

```hcl
# Resource name prefix (used for all resource names)
name_prefix = "dms"

# Source RDS PostgreSQL configuration
rds_postgres_engine_version = "16.1"
rds_postgres_instance_class = "db.t4g.small"
rds_postgres_db_name        = "sourcedb"
rds_postgres_master_user    = "postgres"

# Target Aurora PostgreSQL configuration
aurora_engine_version = "16.8"
aurora_instance_class = "db.t4g.medium"
aurora_db_name        = "targetdb"
aurora_master_user    = "demo"
```

Passwords are auto-generated and output as sensitive values.

## Usage

### 1. Convert Schema (Optional)

If you have an existing schema to migrate:

1. Install AWS SCT locally
2. Connect to source PostgreSQL and convert schema if needed
3. Export converted SQL to `sct/converted_schema.sql`

The schema will be automatically applied to Aurora if the file exists.

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
make init

# Plan changes (optional)
make plan

# Apply infrastructure
make apply

# Get outputs
make outputs
```

### 3. Start DMS Replication

```bash
make start
```

## Next Steps After Deployment

Once Terraform has successfully applied:

1. **Get connection details:**

   ```bash
   make outputs
   ```

2. **Start the DMS replication task:**

   ```bash
   make start
   ```

   This will start the DMS task in CDC mode (full load + ongoing replication).

3. **Verify replication status:**

   ```bash
   # Check DMS task status
   aws dms describe-replication-tasks \
     --filters Name=replication-task-arn,Values=$(jq -r .dms_task_arn.value tf-outputs.json) \
     --query 'ReplicationTasks[0].{Status:Status,PercentComplete:ReplicationTaskStats.PercentComplete,ElapsedTime:ReplicationTaskStats.ElapsedTimeMillis}' \
     --output table
   ```

4. **Connect to databases:**

   ```bash
   # Source RDS PostgreSQL
   psql -h $(jq -r .rds_postgres_endpoint.value tf-outputs.json) \
        -U postgres \
        -d sourcedb \
        -W
   # Password: $(jq -r .rds_postgres_password.value tf-outputs.json)

   # Target Aurora PostgreSQL
   psql -h $(jq -r .aurora_writer_endpoint.value tf-outputs.json) \
        -U demo \
        -d targetdb \
        -W
   # Password: $(jq -r .aurora_password.value tf-outputs.json)
   ```

5. **Monitor replication:**
   - Check CloudWatch logs for DMS replication instance
   - Monitor DMS task metrics in CloudWatch
   - Verify data in target Aurora database

## Run Order

1. `make init` - Initialize Terraform
2. `make plan` - Preview changes (optional)
3. `make apply` - Deploy infrastructure (schema applied automatically if file exists)
4. `make outputs` - Save outputs to `tf-outputs.json`
5. `make start` - Start DMS replication task
6. `make destroy` - Clean up all resources

## Outputs

After running `make outputs`, you can access:

- `aurora_writer_endpoint` - Aurora PostgreSQL connection endpoint
- `aurora_password` - Auto-generated Aurora password (sensitive)
- `rds_postgres_endpoint` - RDS PostgreSQL connection endpoint
- `rds_postgres_password` - Auto-generated RDS PostgreSQL password (sensitive)
- `dms_task_arn` - DMS replication task ARN
- `vpc_id` - VPC ID for reference

## Architecture

- **VPC**: 10.0.0.0/16 with 2 private subnets in different AZs
- **Source RDS PostgreSQL**:
  - Instance class: db.t4g.small
  - Logical replication enabled (required for CDC)
  - CloudWatch logs enabled
- **Target Aurora PostgreSQL**:
  - Single writer instance, class: db.t4g.medium
  - CloudWatch logs enabled
- **DMS**: Replication instance in private subnets, not publicly accessible
- **Security**:
  - RDS accepts connections only from DMS security group
  - Aurora accepts connections only from DMS security group
  - All resources in private subnets with NAT gateway for outbound connectivity

## Notes

- Region is hardcoded to `ap-southeast-2`
- All configuration in `locals.tf` (no variables.tf)
- Resource names use `name_prefix` variable (default: "dms") - change in `locals.tf` to customize
- Passwords are auto-generated via `random_password` resources
- Schema is automatically applied via Lambda function triggered by EventBridge (runs every minute until successful, then disables itself)
- Lambda runs in VPC with access to Aurora private subnet
- CloudWatch log groups are created before RDS/Aurora to control retention (1 day) and tags
- Logical replication is enabled on source RDS PostgreSQL (required for CDC with DMS)

## Cleanup

To destroy all resources created by Terraform:

```bash
make destroy
```

This will:

- Destroy all AWS resources (VPC, RDS, Aurora, DMS, Lambda, etc.)
- Clean up generated files (`tf-outputs.json`, Lambda zip files, etc.)

**Note:** Ensure you have backed up any important data before running destroy, as this operation is irreversible.
