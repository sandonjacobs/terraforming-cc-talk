resource "confluent_kafka_topic" "noaa_zones_inbound" {
  kafka_cluster {
    id = local.kafka.cluster_id
  }

  rest_endpoint = local.kafka.rest_endpoint

  topic_name    = "noaa_zones_inbound"
  partitions_count = 6
  config = {
    "cleanup.policy" = "delete"
    "retention.ms" = "604800000" # 7 days
  }
  credentials {
    key    = local.sa_kafka_cluster_mgr.api_key_id
    secret = local.sa_kafka_cluster_mgr.api_key_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

// Assign Roles to `kafka-developer` needed to interact with kafka topics, by convention
resource "confluent_role_binding" "kafka-developer-developer-write-noaa" {
  principal   = "User:${local.kafka_developer.svc_acct_id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka.rbac_crn}/kafka=${local.kafka.cluster_id}/topic=noaa_*"
}

resource "confluent_role_binding" "kafka-developer-developer-read-noaa" {
  principal   = "User:${local.kafka_developer.svc_acct_id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka.rbac_crn}/kafka=${local.kafka.cluster_id}/topic=noaa_*"
}
