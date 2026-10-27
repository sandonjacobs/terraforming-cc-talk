# Offline wiring checks with a mocked provider; nothing here talks to Confluent Cloud.

mock_provider "confluent" {}

variables {
  omar_environment_id       = "env-mock1"
  omar_kafka_cluster_id     = "lkc-mock1"
  omar_kafka_rest_endpoint  = "https://pkc-mock.us-east-1.aws.confluent.cloud:443"
  omar_ida_kafka_api_key    = "kafka-key"
  omar_ida_kafka_api_secret = "kafka-secret"
  omar_ida_cloud_api_key    = "cloud-key"
  omar_ida_cloud_api_secret = "cloud-secret"
}

run "topic_and_connector_match_the_spec" {
  command = apply

  assert {
    condition     = output.orders_topic == "landing-orders" && !strcontains(output.orders_topic, ".")
    error_message = "The landing topic must be landing-orders and contain no dots"
  }

  assert {
    condition     = confluent_connector.orders.config_nonsensitive["connector.class"] == "DatagenSource" && confluent_connector.orders.config_nonsensitive["quickstart"] == "ORDERS"
    error_message = "The connector must be a Datagen Source using the Orders quickstart"
  }

  assert {
    condition     = confluent_connector.orders.config_nonsensitive["output.data.format"] == "AVRO"
    error_message = "The connector must write Avro"
  }

  assert {
    condition     = confluent_connector.orders.config_nonsensitive["kafka.topic"] == "landing-orders"
    error_message = "The connector must write to the landing topic"
  }

  assert {
    condition     = output.orders_connector_name == "orders-datagen-source"
    error_message = "The connector name output is missing"
  }
}

run "topic_names_with_dots_are_rejected" {
  command = plan

  variables {
    orders_topic_name = "landing.orders"
  }

  expect_failures = [var.orders_topic_name]
}
