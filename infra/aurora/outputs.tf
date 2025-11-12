output "writer_endpoint" {
  description = "Aurora writer endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "aurora_sg_id" {
  description = "Aurora security group ID"
  value       = aws_security_group.aurora.id
}

output "dms_sg_id" {
  description = "DMS security group ID"
  value       = aws_security_group.dms.id
}
