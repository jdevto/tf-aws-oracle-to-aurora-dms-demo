# Aurora PostgreSQL cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier              = "${var.name_prefix}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = var.engine_version
  database_name                   = var.db_name
  master_username                 = var.master_user
  master_password                 = var.master_password
  db_subnet_group_name            = var.db_subnet_group_id
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  skip_final_snapshot             = true
  deletion_protection             = false
  enabled_cloudwatch_logs_exports = ["postgresql"]

  depends_on = [aws_cloudwatch_log_group.aurora_postgresql]

  tags = {
    Name = "${var.name_prefix}-aurora-cluster"
  }
}

# Aurora cluster instance (writer)
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.name_prefix}-aurora-instance"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  tags = {
    Name = "${var.name_prefix}-aurora-instance"
  }
}
