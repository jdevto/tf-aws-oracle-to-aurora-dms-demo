# CloudWatch Log Group for RDS PostgreSQL logs
resource "aws_cloudwatch_log_group" "rds_postgresql" {
  name              = "/aws/rds/instance/${var.name_prefix}-rds-postgres/postgresql"
  retention_in_days = 1

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }

  tags = {
    Name = "${var.name_prefix}-rds-postgres-postgresql-logs"
  }
}
