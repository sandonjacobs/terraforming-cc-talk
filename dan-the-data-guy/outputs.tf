# Output names become .env keys via scripts/publish-env.sh (prefix DAN_, uppercased).

output "curated_topics" {
  value = join(",", [
    var.curated_orders_topic,
  ])
}
