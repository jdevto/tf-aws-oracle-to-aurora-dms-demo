# Oracle to Aurora PostgreSQL DMS Migration

Terraform infrastructure for migrating on-prem Oracle database to Aurora PostgreSQL using AWS DMS with full load + CDC capabilities.

## Overview

This solution provisions:

- VPC with private subnets in ap-southeast-2
- Aurora PostgreSQL cluster (minimum instance class: db.t4g.medium)
- AWS DMS replication instance and endpoints
- Security groups configured for Aurora and DMS communication

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- PostgreSQL client (psql) installed locally (for schema application)
- jq installed (for Makefile targets)
- Oracle database configured for CDC (see `sct/README.md`)

## Configuration

All configuration is in `infra/locals.tf`. Update the following before applying:

```hcl
oracle_host         = "your-oracle-host"
oracle_user         = "dms_user"
oracle_service_name = "ORCL"
```

Passwords are auto-generated and output as sensitive values.

## Usage

### 1. Prepare Oracle for CDC

Follow the instructions in `sct/README.md` to:

- Enable supplemental logging and archiving
- Create DMS user with required privileges

### 2. Convert Schema

1. Install AWS SCT locally
2. Connect to Oracle and convert schema to PostgreSQL
3. Export converted SQL to `sct/converted_schema.sql`

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
make init

# Apply infrastructure
make apply

# Get outputs
make outputs
```

### 4. Start DMS Replication

```bash
make start
```

## Run Order

1. `make init` - Initialize Terraform
2. `make apply` - Deploy infrastructure (schema applied automatically if file exists)
3. `make outputs` - Save outputs to `tf-outputs.json`
4. `make start` - Start DMS replication task

## Outputs

After running `make outputs`, you can access:

- `aurora_writer_endpoint` - Aurora PostgreSQL connection endpoint
- `aurora_password` - Auto-generated Aurora password (sensitive)
- `dms_task_arn` - DMS replication task ARN
- `vpc_id` - VPC ID for reference

## Architecture

- **VPC**: 10.0.0.0/16 with 2 private subnets in different AZs
- **Aurora**: Single writer instance, minimum class (db.t4g.medium)
- **DMS**: Replication instance in private subnets, not publicly accessible
- **Security**: Aurora accepts connections only from DMS security group

## Notes

- Region is hardcoded to `ap-southeast-2`
- All configuration in `locals.tf` (no variables.tf)
- Passwords are auto-generated via `random_password` resources
- Schema is automatically applied via Lambda function triggered by EventBridge (runs every minute until successful, then disables itself)
- Lambda runs in VPC with access to Aurora private subnet
- Oracle connectivity must be configured on-prem firewall to allow DMS security group CIDR
