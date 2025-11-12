# Aurora PostgreSQL cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier              = "dms-demo-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = var.engine_version
  database_name                   = var.db_name
  master_username                 = var.master_user
  master_password                 = var.master_password
  db_subnet_group_name            = var.db_subnet_group_id
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  skip_final_snapshot             = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "dms-demo-aurora-cluster"
  }
}

# Aurora cluster instance (writer)
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "dms-demo-aurora-instance"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  tags = {
    Name = "dms-demo-aurora-instance"
  }
}
