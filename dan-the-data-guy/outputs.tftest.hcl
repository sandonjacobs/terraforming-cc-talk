# Offline wiring checks with a mocked provider; nothing here talks to Confluent Cloud.

mock_provider "confluent" {}

variables {
  omar_organization_id                = "00000000-0000-0000-0000-000000000001"
  omar_environment_id                 = "env-mock1"
  omar_environment_name               = "demo-env"
  omar_kafka_cluster_name             = "demo-cluster"
  omar_schema_registry_id             = "lsrc-mock1"
  omar_schema_registry_rest_endpoint  = "https://psrc-mock.us-east-1.aws.confluent.cloud"
  omar_flink_compute_pool_id          = "lfcp-mock1"
  omar_flink_rest_endpoint            = "https://flink.us-east-1.aws.confluent.cloud"
  omar_dan_service_account_id         = "sa-mock01"
  omar_dan_schema_registry_api_key    = "sr-key"
  omar_dan_schema_registry_api_secret = "sr-secret"
  omar_dan_flink_api_key              = "flink-key"
  omar_dan_flink_api_secret           = "flink-secret"
  ida_orders_topic                    = "landing-orders"
  ali_events_topic                    = "app-events"
}

run "schema_and_statements_match_the_spec" {
  command = apply

  assert {
    condition     = confluent_schema.app_events.subject_name == "app-events-value" && confluent_schema.app_events.format == "AVRO"
    error_message = "Ali's topic must have an Avro schema under the app-events-value subject"
  }

  assert {
    condition     = length(confluent_flink_statement.statement) == 1
    error_message = "Expected one Flink statement"
  }

  assert {
    condition = alltrue([
      for s in values(confluent_flink_statement.statement) :
      s.properties["sql.current-catalog"] == "demo-env" && s.properties["sql.current-database"] == "demo-cluster"
    ])
    error_message = "Every statement must run in Omar's environment and cluster"
  }

  assert {
    condition = (
      strcontains(confluent_flink_statement.statement["curate-orders"].statement, "`landing-orders`") &&
      strcontains(confluent_flink_statement.statement["curate-orders"].statement, "`curated-orders`")
    )
    error_message = "The statement must read landing-orders and write curated-orders"
  }

  assert {
    condition     = !strcontains(confluent_flink_statement.statement["curate-orders"].statement, "$${")
    error_message = "SQL templates have unrendered placeholders"
  }
}

run "output_lists_curated_topics_without_dots" {
  command = apply

  assert {
    condition     = output.curated_topics == "curated-orders"
    error_message = "curated_topics must list the curated topic"
  }

  assert {
    condition     = !strcontains(output.curated_topics, ".")
    error_message = "Topic names must not contain dots"
  }
}

run "dotted_curated_names_are_rejected" {
  command = plan

  variables {
    curated_orders_topic = "curated.orders"
  }

  expect_failures = [var.curated_orders_topic]
}
