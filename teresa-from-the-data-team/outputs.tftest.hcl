# Offline wiring checks with a mocked provider; nothing here talks to Confluent Cloud.

mock_provider "confluent" {}

variables {
  omar_environment_id              = "env-mock1"
  omar_kafka_cluster_id            = "lkc-mock1"
  omar_kafka_rest_endpoint         = "https://pkc-mock.us-east-2.aws.confluent.cloud:443"
  omar_teresa_kafka_api_key        = "kafka-key"
  omar_teresa_kafka_api_secret     = "kafka-secret"
  omar_teresa_tableflow_api_key    = "tableflow-key"
  omar_teresa_tableflow_api_secret = "tableflow-secret"
  dan_curated_topics               = "curated-orders"
}

run "tableflow_is_iceberg_on_managed_storage" {
  command = apply

  assert {
    condition     = confluent_tableflow_topic.curated_orders.display_name == "curated-orders"
    error_message = "Tableflow must be enabled on curated-orders"
  }

  assert {
    condition     = toset(confluent_tableflow_topic.curated_orders.table_formats) == toset(["ICEBERG"])
    error_message = "The table format must be Iceberg only"
  }

  assert {
    condition = alltrue([
      length(confluent_tableflow_topic.curated_orders.managed_storage) == 1,
      length(confluent_tableflow_topic.curated_orders.byob_aws) == 0,
      length(confluent_tableflow_topic.curated_orders.azure_data_lake_storage_gen_2) == 0,
      length(confluent_tableflow_topic.curated_orders.google_cloud_storage) == 0,
    ])
    error_message = "Storage must be Confluent-managed: no bucket or provider integration (FR-019)"
  }

  assert {
    condition     = output.tableflow_topic == "curated-orders" && output.table_formats == "ICEBERG"
    error_message = "Outputs tableflow_topic and table_formats must match the env-file contract"
  }
}

run "fails_when_dan_has_not_published_the_topic" {
  command = plan

  variables {
    dan_curated_topics = "curated-other"
  }

  expect_failures = [terraform_data.dan_has_applied]
}

run "dotted_topic_names_are_rejected" {
  command = plan

  variables {
    curated_orders_topic = "curated.orders"
  }

  expect_failures = [var.curated_orders_topic]
}
