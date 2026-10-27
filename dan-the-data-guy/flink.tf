locals {
  sql_vars = {
    orders_topic         = var.ida_orders_topic
    curated_orders_topic = var.curated_orders_topic
  }

  # Every statement runs in Omar's environment (Flink catalog) and Kafka cluster (Flink database).
  statement_properties = {
    "sql.current-catalog"  = var.omar_environment_name
    "sql.current-database" = var.omar_kafka_cluster_name
  }

  statements = {
    "curate-orders" = "curate-orders.sql"
  }
}

resource "confluent_flink_statement" "statement" {
  for_each = local.statements

  statement_name = each.key
  statement      = templatefile("${path.module}/flink-sql/${each.value}", local.sql_vars)
  properties     = local.statement_properties
  rest_endpoint  = var.omar_flink_rest_endpoint

  organization {
    id = var.omar_organization_id
  }

  environment {
    id = var.omar_environment_id
  }

  compute_pool {
    id = var.omar_flink_compute_pool_id
  }

  principal {
    id = var.omar_dan_service_account_id
  }

  credentials {
    key    = var.omar_dan_flink_api_key
    secret = var.omar_dan_flink_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
