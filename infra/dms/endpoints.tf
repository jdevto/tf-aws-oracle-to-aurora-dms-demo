# Source endpoint (RDS PostgreSQL)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.name_prefix}-rds-postgres"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = var.rds_postgres_endpoint
  port          = var.rds_postgres_port
  username      = var.rds_postgres_user
  password      = var.rds_postgres_password
  database_name = var.rds_postgres_db_name

  ssl_mode = "require"

  extra_connection_attributes = ""

  tags = {
    Name = "${var.name_prefix}-rds-postgres"
  }
}

# Target endpoint (Aurora PostgreSQL)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${var.name_prefix}-aurora-target"
  endpoint_type = "target"
  engine_name   = "aurora-postgresql"

  server_name   = var.aurora_writer_endpoint
  port          = 5432
  username      = var.aurora_master_user
  password      = var.aurora_master_password
  database_name = var.aurora_db_name

  extra_connection_attributes = "executeTimeout=120"

  tags = {
    Name = "${var.name_prefix}-aurora-target"
  }
}
