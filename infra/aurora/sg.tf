# Security group for Aurora
resource "aws_security_group" "aurora" {
  name        = "aurora-dms-demo-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from DMS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dms.id]
  }

  dynamic "ingress" {
    for_each = var.lambda_sg_id != "" ? [1] : []
    content {
      description     = "PostgreSQL from Lambda"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [var.lambda_sg_id]
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-dms-demo-sg"
  }
}

# Security group for DMS
resource "aws_security_group" "dms" {
  name        = "dms-demo-sg"
  description = "Security group for DMS replication instance"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dms-demo-sg"
  }
}
