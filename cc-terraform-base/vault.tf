resource "vault_generic_secret" "cc_kafka_app_manager_api_key" {
    
  path = "${var.vault_path}/kafka"

  data_json = jsonencode({
    kafka_bootstrap_server = confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint
    kafka_app_manager_api_key = confluent_api_key.app-manager-kafka-api-key.id
    kafka_app_manager_api_secret = confluent_api_key.app-manager-kafka-api-key.secret
  })

  depends_on = [
    confluent_api_key.app-manager-kafka-api-key
  ]

  lifecycle {
    prevent_destroy = false
  }
}

resource "vault_generic_secret" "cc_kafka_schema_registry_api_key" {
    
  path = "${var.vault_path}/schema-registry"

  data_json = jsonencode({
    schema_registry_endpoint = data.confluent_schema_registry_cluster.advanced.rest_endpoint
    schema_registry_api_key = confluent_api_key.env-manager-schema-registry-api-key.id
    schema_registry_api_secret = confluent_api_key.env-manager-schema-registry-api-key.secret
  })

  depends_on = [
    confluent_api_key.env-manager-schema-registry-api-key,
    data.confluent_schema_registry_cluster.advanced
  ]

  lifecycle {
    prevent_destroy = false
  }
}
