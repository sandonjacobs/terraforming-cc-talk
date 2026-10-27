# Offline wiring checks with a mocked provider; nothing here talks to Confluent Cloud.

mock_provider "confluent" {}

variables {
  omar_kafka_cluster_id     = "lkc-mock1"
  omar_kafka_rest_endpoint  = "https://pkc-mock.us-east-1.aws.confluent.cloud:443"
  omar_ali_kafka_api_key    = "kafka-key"
  omar_ali_kafka_api_secret = "kafka-secret"
}

run "events_topic_is_scoped_and_dotless" {
  command = apply

  assert {
    condition     = output.events_topic == "app-events"
    error_message = "Ali's topic must be app-events"
  }

  assert {
    condition     = startswith(output.events_topic, "app-") && !strcontains(output.events_topic, ".")
    error_message = "Topic must start with app- and contain no dots"
  }
}

run "dotted_topic_names_are_rejected" {
  command = plan

  variables {
    events_topic_name = "app.events"
  }

  expect_failures = [var.events_topic_name]
}
