resource "confluent_kafka_topic" "noaa_zones_inbound" {
  kafka_cluster {
    id = local.kafka_cluster_id
  }

  rest_endpoint = local.kafka_rest_endpoint

  topic_name    = "noaa_zones_inbound"
  partitions_count = 6
  config = {
    "cleanup.policy" = "delete"
    "retention.ms" = "604800000" # 7 days
  }
  credentials {
    key    = local.kafka_app_manager_api_key
    secret = local.kafka_app_manager_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}