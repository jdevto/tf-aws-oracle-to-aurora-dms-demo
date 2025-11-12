variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Aurora"
  type        = list(string)
}

variable "db_subnet_group_id" {
  description = "DB subnet group ID"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
}

variable "instance_class" {
  description = "Aurora instance class"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "master_user" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "lambda_sg_id" {
  description = "Lambda security group ID"
  type        = string
  default     = ""
}
