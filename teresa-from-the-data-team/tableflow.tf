# Teresa turns Dan's curated-orders topic into an Iceberg table in Confluent-managed storage.
# No bucket and no provider integration are needed.

# Fails the plan when Dan has not published the topic (a stale or hand-edited .env).
resource "terraform_data" "dan_has_applied" {
  lifecycle {
    precondition {
      condition     = contains(split(",", var.dan_curated_topics), var.curated_orders_topic)
      error_message = "${var.curated_orders_topic} is not in DAN_CURATED_TOPICS: apply Dan's workspace first."
    }
  }
}

# Fails the plan when the topic is not in the cluster (for example Dan was destroyed but .env
# still lists it). Read with Teresa's own Kafka key.
data "confluent_kafka_topic" "curated_orders" {
  topic_name    = var.curated_orders_topic
  rest_endpoint = var.omar_kafka_rest_endpoint

  kafka_cluster {
    id = var.omar_kafka_cluster_id
  }

  credentials {
    key    = var.omar_teresa_kafka_api_key
    secret = var.omar_teresa_kafka_api_secret
  }
}

resource "confluent_tableflow_topic" "curated_orders" {
  display_name  = var.curated_orders_topic
  table_formats = ["ICEBERG"]

  # An empty block selects Confluent-managed storage (research.md item 15, "Verify" that it may
  # not be omitted).
  managed_storage {}

  environment {
    id = var.omar_environment_id
  }

  kafka_cluster {
    id = var.omar_kafka_cluster_id
  }

  credentials {
    key    = var.omar_teresa_kafka_api_key
    secret = var.omar_teresa_kafka_api_secret
  }

  depends_on = [terraform_data.dan_has_applied, data.confluent_kafka_topic.curated_orders]
}
