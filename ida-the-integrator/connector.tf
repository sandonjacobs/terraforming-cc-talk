# One managed Datagen Source connector generates sample orders and writes them to the landing topic
# as Avro. There is no external API to call. Property names follow Confluent's Datagen Source
# connector documentation; confirm them on the first live apply (see README).

resource "confluent_connector" "orders" {
  environment {
    id = var.omar_environment_id
  }

  kafka_cluster {
    id = var.omar_kafka_cluster_id
  }

  config_sensitive = {
    "kafka.api.key"    = var.omar_ida_kafka_api_key
    "kafka.api.secret" = var.omar_ida_kafka_api_secret
  }

  config_nonsensitive = {
    "connector.class"    = "DatagenSource"
    "name"               = "orders-datagen-source"
    "kafka.auth.mode"    = "KAFKA_API_KEY"
    "kafka.topic"        = confluent_kafka_topic.orders.topic_name
    "quickstart"         = "ORDERS"
    "output.data.format" = "AVRO"
    "max.interval"       = tostring(var.orders_interval_ms)
    "tasks.max"          = "1"
  }

  lifecycle {
    prevent_destroy = false
  }
}
