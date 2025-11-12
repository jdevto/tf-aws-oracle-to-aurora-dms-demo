locals {
  region   = "ap-southeast-2"
  vpc_cidr = "10.0.0.0/16"
  azs      = ["ap-southeast-2a", "ap-southeast-2b"]

  # Aurora configuration
  aurora_engine_version = "16.8"
  aurora_instance_class = "db.t4g.medium" # db.t4g.small not supported for Aurora PostgreSQL 16.3
  aurora_db_name        = "targetdb"
  aurora_master_user    = "demo"

  layer_zip_url = "https://github.com/serverlessia/lambda-psycopg2-layer/archive/refs/tags/python3.13-v4.zip"

  # Oracle connection (user must update these)
  oracle_host         = "your-oracle-host"
  oracle_port         = 1521
  oracle_user         = "dms_user"
  oracle_service_name = "ORCL"

  # DMS configuration
  dms_instance_class = "dms.t3.small"

  # Table mapping rules - include all tables
  table_mapping_rules = jsonencode({
    rules = [{
      "rule-type"   = "selection"
      "rule-id"     = "1"
      "rule-name"   = "include-all"
      "rule-action" = "include"
      "object-locator" = {
        "schema-name" = "%"
        "table-name"  = "%"
      }
    }]
  })
}
