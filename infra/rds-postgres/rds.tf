# DB parameter group for logical replication (required for CDC)
resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-rds-postgres-pg"
  family = "postgres16"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.name_prefix}-rds-postgres-pg"
  }
}

# RDS PostgreSQL instance
resource "aws_db_instance" "main" {
  identifier     = "${var.name_prefix}-rds-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.master_user
  password = var.master_password

  db_subnet_group_name   = var.db_subnet_group_id
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Enable logical replication for CDC
  parameter_group_name = aws_db_parameter_group.main.name

  depends_on = [aws_cloudwatch_log_group.rds_postgresql]

  tags = {
    Name = "${var.name_prefix}-rds-postgres"
  }
}
