# Source endpoint (Oracle)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "dms-demo-oracle-source"
  endpoint_type = "source"
  engine_name   = "oracle"

  server_name   = var.oracle_host
  port          = var.oracle_port
  username      = var.oracle_user
  password      = var.oracle_password
  database_name = var.oracle_service_name

  ssl_mode = "none"

  extra_connection_attributes = "useLogminerReader=Y;archivedLogDestId=1"

  tags = {
    Name = "dms-demo-oracle-source"
  }
}

# Target endpoint (Aurora PostgreSQL)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "dms-demo-aurora-target"
  endpoint_type = "target"
  engine_name   = "aurora-postgresql"

  server_name   = var.aurora_writer_endpoint
  port          = 5432
  username      = var.aurora_master_user
  password      = var.aurora_master_password
  database_name = var.aurora_db_name

  extra_connection_attributes = "executeTimeout=120"

  tags = {
    Name = "dms-demo-aurora-target"
  }
}
