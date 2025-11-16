# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Random passwords (exclude DMS-unsupported characters: ;+%)
resource "random_password" "aurora_password" {
  length           = 16
  special          = true
  override_special = "!#$&*()-_=[]{}|:?"
}

resource "random_password" "rds_postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$&*()-_=[]{}|:?"
}

# Aurora module (created first to provide DMS security group)
module "aurora" {
  source = "./aurora"

  name_prefix        = local.name_prefix
  vpc_id             = aws_vpc.main.id
  subnet_ids         = aws_subnet.private[*].id
  db_subnet_group_id = aws_db_subnet_group.aurora.id

  engine_version  = local.aurora_engine_version
  instance_class  = local.aurora_instance_class
  db_name         = local.aurora_db_name
  master_user     = local.aurora_master_user
  master_password = random_password.aurora_password.result
  lambda_sg_id    = aws_security_group.lambda.id
}

  # RDS PostgreSQL module
  module "rds_postgres" {
    source = "./rds-postgres"

    name_prefix        = local.name_prefix
    vpc_id             = aws_vpc.main.id
    subnet_ids         = aws_subnet.private[*].id
    db_subnet_group_id = aws_db_subnet_group.rds_postgres.id

    engine_version  = local.rds_postgres_engine_version
    instance_class  = local.rds_postgres_instance_class
    db_name         = local.rds_postgres_db_name
    master_user     = local.rds_postgres_master_user
    master_password = random_password.rds_postgres_password.result
    dms_sg_id       = module.aurora.dms_sg_id
    lambda_sg_id    = aws_security_group.lambda.id
  }

# DMS module
module "dms" {
  source = "./dms"

  # Network configuration
  name_prefix                 = local.name_prefix
  vpc_id                      = aws_vpc.main.id
  subnet_ids                  = aws_subnet.private[*].id
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id

  # DMS instance configuration
  dms_instance_class = local.dms_instance_class

  # Target (Aurora) configuration
  aurora_writer_endpoint = module.aurora.writer_endpoint
  aurora_db_name         = local.aurora_db_name
  aurora_master_user     = local.aurora_master_user
  aurora_master_password = random_password.aurora_password.result
  aurora_sg_id           = module.aurora.aurora_sg_id

  # Source (RDS PostgreSQL) configuration
  rds_postgres_endpoint = module.rds_postgres.endpoint
  rds_postgres_port     = 5432
  rds_postgres_user     = local.rds_postgres_master_user
  rds_postgres_password = random_password.rds_postgres_password.result
  rds_postgres_db_name  = local.rds_postgres_db_name

  # Security groups
  dms_sg_id = module.aurora.dms_sg_id

  # DMS task configuration
  table_mapping_rules = local.table_mapping_rules
  random_suffix       = random_id.suffix.hex
}
