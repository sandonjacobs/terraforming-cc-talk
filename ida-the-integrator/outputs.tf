# Output names become .env keys via scripts/publish-env.sh (prefix IDA_, uppercased).

output "orders_topic" {
  value = confluent_kafka_topic.orders.topic_name
}

output "orders_connector_name" {
  value = confluent_connector.orders.config_nonsensitive["name"]
}
