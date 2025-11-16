# CloudWatch Log Group for Aurora PostgreSQL logs
resource "aws_cloudwatch_log_group" "aurora_postgresql" {
  name              = "/aws/rds/cluster/${var.name_prefix}-aurora-cluster/postgresql"
  retention_in_days = 1

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }

  tags = {
    Name = "${var.name_prefix}-aurora-postgresql-logs"
  }
}
