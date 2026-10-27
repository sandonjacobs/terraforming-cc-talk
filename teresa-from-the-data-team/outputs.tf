# Output names become .env keys via scripts/publish-env.sh (prefix TERESA_, uppercased).

output "tableflow_topic" {
  value = confluent_tableflow_topic.curated_orders.display_name
}

output "table_formats" {
  value = join(",", confluent_tableflow_topic.curated_orders.table_formats)
}
