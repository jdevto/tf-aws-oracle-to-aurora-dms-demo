variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for DMS"
  type        = list(string)
}

variable "replication_subnet_group_id" {
  description = "DMS replication subnet group ID"
  type        = string
}

variable "dms_instance_class" {
  description = "DMS replication instance class"
  type        = string
}

variable "aurora_writer_endpoint" {
  description = "Aurora writer endpoint"
  type        = string
}

variable "aurora_db_name" {
  description = "Aurora database name"
  type        = string
}

variable "aurora_master_user" {
  description = "Aurora master username"
  type        = string
}

variable "aurora_master_password" {
  description = "Aurora master password"
  type        = string
  sensitive   = true
}

variable "aurora_sg_id" {
  description = "Aurora security group ID"
  type        = string
}

variable "dms_sg_id" {
  description = "DMS security group ID"
  type        = string
}

variable "rds_postgres_endpoint" {
  description = "RDS PostgreSQL endpoint"
  type        = string
}

variable "rds_postgres_port" {
  description = "RDS PostgreSQL port"
  type        = number
}

variable "rds_postgres_user" {
  description = "RDS PostgreSQL username"
  type        = string
}

variable "rds_postgres_password" {
  description = "RDS PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "rds_postgres_db_name" {
  description = "RDS PostgreSQL database name"
  type        = string
}

variable "table_mapping_rules" {
  description = "DMS table mapping rules JSON"
  type        = string
}

variable "random_suffix" {
  description = "Random suffix for unique resource names"
  type        = string
}
