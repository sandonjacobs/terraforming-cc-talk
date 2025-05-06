data "vault_generic_secret" "confluent_environment" {
  path = "${var.vault_path}/confluent_environment"
}
data "vault_generic_secret" "cc_kafka" {
  path = "${var.vault_path}/kafka"
}

data "vault_generic_secret" "kafka_cluster_mgr" {
  path = "${var.vault_path}/kafka_cluster_mgr"
}

# data "vault_generic_secret" "cc_schema_registry" {
#   path = "${var.vault_path}/schema-registry"
# }
#
# data "vault_generic_secret" "flink_weather_compute" {
#   path = "${var.vault_path}/flink_weather_compute"
# }

locals {
  confluent_env_id = data.vault_generic_secret.confluent_environment.data["cc_environment_id"]
  confluent_env_name = data.vault_generic_secret.confluent_environment.data["cc_environment_display_name"]
  confluent_org_id = data.vault_generic_secret.confluent_environment.data["cc_org_id"]

  kafka_bootstrap_server = data.vault_generic_secret.cc_kafka.data["kafka_bootstrap_server"]
  kafka_rest_endpoint = data.vault_generic_secret.cc_kafka.data["kafka_rest_endpoint"]
  kafka_cluster_id = data.vault_generic_secret.cc_kafka.data["kafka_cluster_id"]
  kafka_cluster_name = data.vault_generic_secret.cc_kafka.data["kafka_cluster_display_name"]

  kafka_cluster_mgr_api_key = data.vault_generic_secret.kafka_cluster_mgr.data["api_key"]
  kafka_cluster_mgr_secret = data.vault_generic_secret.kafka_cluster_mgr.data["secret"]

  # schema_registry_endpoint = data.vault_generic_secret.cc_schema_registry.data["schema_registry_endpoint"]
  # schema_registry_id = data.vault_generic_secret.cc_schema_registry.data["schema_registry_id"]
  # schema_registry_api_key = data.vault_generic_secret.cc_schema_registry.data["schema_registry_api_key"]
  # schema_registry_api_secret = data.vault_generic_secret.cc_schema_registry.data["schema_registry_api_secret"]
  #
  # flink_weather_compute_id = data.vault_generic_secret.flink_weather_compute.data["flink_compute_pool_id"]
  # flink_stmt_runner_id = data.vault_generic_secret.flink_weather_compute.data["flink_stmt_runner_id"]
  # flink_weather_region_rest_endpoint = data.vault_generic_secret.flink_weather_compute.data["flink_region_rest_endpoint"]
  # flink_api_key = data.vault_generic_secret.flink_weather_compute.data["flink_api_key"]
  # flink_api_secret = data.vault_generic_secret.flink_weather_compute.data["flink_api_secret"]

}