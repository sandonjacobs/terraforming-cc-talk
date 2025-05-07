// Account to Manage Kafka Clusters
resource "confluent_service_account" "kafka-cluster-manager" {
  display_name = "${var.cc_env_display_name}-kafka-cluster-manager"
  description = "Manager Kafka Clusters"
}

// Assign Roles to `kafka-cluster-manager` needed to manage defined Kafka Cluster(s)
resource "confluent_role_binding" "kafka-cluster-manager-cluster-admin" {
  principal   = "User:${confluent_service_account.kafka-cluster-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn
}

resource "confluent_api_key" "kafka-cluster-manager-api-key" {
  display_name = "${confluent_service_account.kafka-cluster-manager.display_name}-api-key"
  description  = "Kafka API Key that is owned by 'kafka-cluster-manager' service account"
  owner {
    id          = confluent_service_account.kafka-cluster-manager.id
    api_version = confluent_service_account.kafka-cluster-manager.api_version
    kind        = confluent_service_account.kafka-cluster-manager.kind
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
    confluent_service_account.kafka-cluster-manager
  ]
}
