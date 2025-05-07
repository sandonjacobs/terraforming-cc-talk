// Service Account for Kafka Developers
resource "confluent_service_account" "flink-developer" {
  display_name = "${var.cc_env_display_name}-flink-developer"
  description = "flink developer"
}

resource "confluent_api_key" "flink-developer" {
  display_name = "${confluent_service_account.flink-developer.display_name}-api-key"
  description  = "API Key that is owned by 'flink-developer' service account"
  owner {
    id          = confluent_service_account.flink-developer.id
    api_version = confluent_service_account.flink-developer.api_version
    kind        = confluent_service_account.flink-developer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [
    confluent_service_account.flink-developer
  ]
}

resource "confluent_role_binding" "flink-developer" {
  principal   = "User:${confluent_service_account.flink-developer.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.cc_env.resource_name
}

resource "confluent_role_binding" "flink-developer-data-steward" {
  principal   = "User:${confluent_service_account.flink-developer.id}"
  role_name   = "DataSteward"
  crn_pattern = confluent_environment.cc_env.resource_name
}
