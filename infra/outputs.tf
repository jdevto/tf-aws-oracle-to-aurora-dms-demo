output "aurora_writer_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = module.aurora.writer_endpoint
}

output "aurora_password" {
  description = "Aurora master password"
  value       = random_password.aurora_password.result
  sensitive   = true
}

output "rds_postgres_password" {
  description = "RDS PostgreSQL password"
  value       = random_password.rds_postgres_password.result
  sensitive   = true
}

output "rds_postgres_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds_postgres.endpoint
}

output "dms_task_arn" {
  description = "DMS replication task ARN"
  value       = module.dms.task_arn
}

output "dms_replication_instance_arn" {
  description = "DMS replication instance ARN"
  value       = module.dms.replication_instance_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}
