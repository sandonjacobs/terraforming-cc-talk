

// 'kafka-manager' service account is required in this configuration to create 'purchase' topic and grant ACLs
// to 'app-producer' and 'app-consumer' service accounts.
resource "confluent_service_account" "kafka-manager" {
  display_name = "${var.cc_kafka_cluster_name}-kafka-manager"
  description  = "Service account to manage Kafka cluster"
}

resource "confluent_role_binding" "kafka-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.kafka-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn
}

resource "confluent_api_key" "kafka-manager-api-key" {
  display_name = "kafka-manager-api-key"
  description  = "Kafka API Key that is owned by 'kafka-manager' service account"
  owner {
    id          = confluent_service_account.kafka-manager.id
    api_version = confluent_service_account.kafka-manager.api_version
    kind        = confluent_service_account.kafka-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  # The goal is to ensure that confluent_role_binding.kafka-manager-kafka-cluster-admin is created before
  # confluent_api_key.kafka-manager-kafka-api-key is used to create instances of
  # confluent_kafka_topic, confluent_kafka_acl resources.

  # 'depends_on' meta-argument is specified in confluent_api_key.kafka-manager-kafka-api-key to avoid having
  # multiple copies of this definition in the configuration which would happen if we specify it in
  # confluent_kafka_topic, confluent_kafka_acl resources instead.
  depends_on = [
    confluent_role_binding.kafka-manager-kafka-cluster-admin
  ]
}
