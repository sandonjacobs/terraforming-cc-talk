# Output names become .env keys via scripts/publish-env.sh (prefix ALI_, uppercased).

output "events_topic" {
  value = confluent_kafka_topic.events.topic_name
}
