output "endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.address
}

output "rds_postgres_sg_id" {
  description = "RDS PostgreSQL security group ID"
  value       = aws_security_group.rds_postgres.id
}
