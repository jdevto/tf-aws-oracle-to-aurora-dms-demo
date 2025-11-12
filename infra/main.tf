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

resource "random_password" "oracle_password" {
  length           = 16
  special          = true
  override_special = "!#$&*()-_=[]{}|:?"
}

# Aurora module
module "aurora" {
  source = "./aurora"

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

# DMS module
module "dms" {
  source = "./dms"

  vpc_id                      = aws_vpc.main.id
  subnet_ids                  = aws_subnet.private[*].id
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id

  dms_instance_class = local.dms_instance_class

  aurora_writer_endpoint = module.aurora.writer_endpoint
  aurora_db_name         = local.aurora_db_name
  aurora_master_user     = local.aurora_master_user
  aurora_master_password = random_password.aurora_password.result

  aurora_sg_id = module.aurora.aurora_sg_id
  dms_sg_id    = module.aurora.dms_sg_id

  oracle_host         = local.oracle_host
  oracle_port         = local.oracle_port
  oracle_user         = local.oracle_user
  oracle_password     = random_password.oracle_password.result
  oracle_service_name = local.oracle_service_name

  table_mapping_rules = local.table_mapping_rules
  random_suffix       = random_id.suffix.hex
}
