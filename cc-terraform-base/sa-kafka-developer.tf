// Service Account for Kafka Developers
resource "confluent_service_account" "kafka-developer" {
  display_name = "${var.cc_env_display_name}-kafka-developer"
  description = "Manager Kafka Clusters"
}

resource "confluent_api_key" "kafka-developer" {
  display_name = "${confluent_service_account.kafka-developer.display_name}-api-key"
  description  = "Kafka API Key that is owned by 'kafka-developer' service account"
  owner {
    id          = confluent_service_account.kafka-developer.id
    api_version = confluent_service_account.kafka-developer.api_version
    kind        = confluent_service_account.kafka-developer.kind
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
    confluent_service_account.kafka-developer
  ]
}

resource "confluent_role_binding" "kafka-developer-data-steward" {
  principal   = "User:${confluent_service_account.kafka-developer.id}"
  role_name   = "DataSteward"
  crn_pattern = confluent_environment.cc_env.resource_name
}

