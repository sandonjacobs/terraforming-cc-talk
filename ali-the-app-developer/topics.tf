resource "confluent_kafka_topic" "events" {
  topic_name       = var.events_topic_name
  partitions_count = 1
  rest_endpoint    = var.omar_kafka_rest_endpoint

  kafka_cluster {
    id = var.omar_kafka_cluster_id
  }

  credentials {
    key    = var.omar_ali_kafka_api_key
    secret = var.omar_ali_kafka_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
