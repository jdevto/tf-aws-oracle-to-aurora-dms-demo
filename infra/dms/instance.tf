# DMS replication instance
resource "aws_dms_replication_instance" "main" {
  replication_instance_id     = "${var.name_prefix}-replication-instance"
  replication_instance_class  = var.dms_instance_class
  replication_subnet_group_id = var.replication_subnet_group_id
  vpc_security_group_ids      = [var.dms_sg_id]
  publicly_accessible         = false
  allocated_storage           = 50
  apply_immediately           = true
  multi_az                    = false

  tags = {
    Name = "${var.name_prefix}-replication-instance"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role,
    aws_iam_role_policy_attachment.dms_cloudwatch_role
  ]
}
