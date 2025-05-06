resource "vault_generic_secret" "cc_environment" {
  path = "${var.vault_path}/confluent_environment"

  data_json = jsonencode({
    cc_org_id = var.org_id
    cc_environment_display_name = confluent_environment.cc_env.display_name
    cc_environment_id = confluent_environment.cc_env.id
    cloud_provider = var.cloud_provider
    cloud_region = var.cloud_region
  })

  lifecycle {
    prevent_destroy = false
  }
}

resource "vault_generic_secret" "cc_kafka" {
    
  path = "${var.vault_path}/kafka"

  data_json = jsonencode({
    kafka_bootstrap_server = confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint
    kafka_cluster_id = confluent_kafka_cluster.kafka_cluster.id
    kafka_cluster_display_name = confluent_kafka_cluster.kafka_cluster.display_name
    kafka_rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  })

  lifecycle {
    prevent_destroy = false
  }
}

resource "vault_generic_secret" "kafka_cluster_mgr" {
  path      = "${var.vault_path}/kafka_cluster_mgr"
  data_json = jsonencode({
    api_key = confluent_api_key.kafka-cluster-manager-api-key.id
    secret = confluent_api_key.kafka-cluster-manager-api-key.secret
  })

  lifecycle {
    prevent_destroy = false
  }
}

# resource "vault_generic_secret" "cc_schema_registry" {
#
#   path = "${var.vault_path}/schema-registry"
#
#   data_json = jsonencode({
#     schema_registry_endpoint = data.confluent_schema_registry_cluster.advanced.rest_endpoint
#     schema_registry_id = data.confluent_schema_registry_cluster.advanced.id
#     schema_registry_api_key = confluent_api_key.env-manager-schema-registry-api-key.id
#     schema_registry_api_secret = confluent_api_key.env-manager-schema-registry-api-key.secret
#   })
#
#   depends_on = [
#     confluent_api_key.env-manager-schema-registry-api-key,
#     data.confluent_schema_registry_cluster.advanced
#   ]
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# resource "vault_generic_secret" "cc_flink_weather_compute" {
#
#   path = "${var.vault_path}/flink_weather_compute"
#
#   data_json = jsonencode({
#     flink_compute_pool_id = confluent_flink_compute_pool.weather_compute_pool.id
#     flink_compute_pool_name = confluent_flink_compute_pool.weather_compute_pool.display_name
#     flink_region_rest_endpoint = data.confluent_flink_region.main.rest_endpoint
#     flink_api_key = confluent_api_key.flink-statements-runner.id
#     flink_api_secret = confluent_api_key.flink-statements-runner.secret
#     flink_stmt_runner_id = confluent_service_account.statements-runner.id
#   })
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }
