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

variable "oracle_host" {
  description = "Oracle host"
  type        = string
}

variable "oracle_port" {
  description = "Oracle port"
  type        = number
}

variable "oracle_user" {
  description = "Oracle username"
  type        = string
}

variable "oracle_password" {
  description = "Oracle password"
  type        = string
  sensitive   = true
}

variable "oracle_service_name" {
  description = "Oracle service name"
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
