# DMS replication task
resource "aws_dms_replication_task" "main" {
  replication_task_id      = "${var.name_prefix}-replication-task-${var.random_suffix}"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  table_mappings = var.table_mapping_rules

  start_replication_task = false

  tags = {
    Name = "${var.name_prefix}-replication-task"
  }
}
