data "vault_generic_secret" "cc_kafka" {
  path = "${var.vault_path}/kafka"
}

data "vault_generic_secret" "cc_schema_registry" {
  path = "${var.vault_path}/schema-registry"
}

locals {
  kafka_bootstrap_server = data.vault_generic_secret.cc_kafka.data["kafka_bootstrap_server"]
  kafka_rest_endpoint = data.vault_generic_secret.cc_kafka.data["kafka_rest_endpoint"]
  kafka_cluster_id = data.vault_generic_secret.cc_kafka.data["kafka_cluster_id"]
  kafka_app_manager_api_key = data.vault_generic_secret.cc_kafka.data["kafka_app_manager_api_key"]
  kafka_app_manager_api_secret = data.vault_generic_secret.cc_kafka.data["kafka_app_manager_api_secret"]

  schema_registry_endpoint = data.vault_generic_secret.cc_schema_registry.data["schema_registry_endpoint"]
  schema_registry_id = data.vault_generic_secret.cc_schema_registry.data["schema_registry_id"]
  schema_registry_api_key = data.vault_generic_secret.cc_schema_registry.data["schema_registry_api_key"]
  schema_registry_api_secret = data.vault_generic_secret.cc_schema_registry.data["schema_registry_api_secret"]
}