# Output names become .env keys via scripts/publish-env.sh (prefix OMAR_, uppercased).
# Contract: specs/001-persona-terraform-demo/contracts/env-file-contract.md

# ---------------------------------------------------------------- platform values

output "organization_id" {
  value = var.organization_id
}

output "environment_id" {
  value = confluent_environment.cc_env.id
}

output "environment_name" {
  value = confluent_environment.cc_env.display_name
}

output "cloud_region" {
  value = var.cloud_region
}

output "kafka_cluster_id" {
  value = confluent_kafka_cluster.kafka_cluster.id
}

output "kafka_cluster_name" {
  value = confluent_kafka_cluster.kafka_cluster.display_name
}

output "kafka_bootstrap_endpoint" {
  value = confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  value = confluent_kafka_cluster.kafka_cluster.rest_endpoint
}

output "schema_registry_id" {
  value = data.confluent_schema_registry_cluster.advanced.id
}

output "schema_registry_rest_endpoint" {
  value = data.confluent_schema_registry_cluster.advanced.rest_endpoint
}

output "flink_compute_pool_id" {
  value = confluent_flink_compute_pool.pool.id
}

output "flink_rest_endpoint" {
  value = data.confluent_flink_region.region.rest_endpoint
}

# ---------------------------------------------------------------- Ida's credentials

output "ida_service_account_id" {
  value = confluent_service_account.ida.id
}

output "ida_kafka_api_key" {
  value     = confluent_api_key.ida_kafka.id
  sensitive = true
}

output "ida_kafka_api_secret" {
  value     = confluent_api_key.ida_kafka.secret
  sensitive = true
}

output "ida_cloud_api_key" {
  value     = confluent_api_key.ida_cloud.id
  sensitive = true
}

output "ida_cloud_api_secret" {
  value     = confluent_api_key.ida_cloud.secret
  sensitive = true
}

# ---------------------------------------------------------------- Ali's credentials

output "ali_service_account_id" {
  value = confluent_service_account.ali.id
}

output "ali_kafka_api_key" {
  value     = confluent_api_key.ali_kafka.id
  sensitive = true
}

output "ali_kafka_api_secret" {
  value     = confluent_api_key.ali_kafka.secret
  sensitive = true
}

output "ali_schema_registry_api_key" {
  value     = confluent_api_key.ali_schema_registry.id
  sensitive = true
}

output "ali_schema_registry_api_secret" {
  value     = confluent_api_key.ali_schema_registry.secret
  sensitive = true
}

# ---------------------------------------------------------------- Dan's credentials

output "dan_service_account_id" {
  value = confluent_service_account.dan.id
}

output "dan_kafka_api_key" {
  value     = confluent_api_key.dan_kafka.id
  sensitive = true
}

output "dan_kafka_api_secret" {
  value     = confluent_api_key.dan_kafka.secret
  sensitive = true
}

output "dan_schema_registry_api_key" {
  value     = confluent_api_key.dan_schema_registry.id
  sensitive = true
}

output "dan_schema_registry_api_secret" {
  value     = confluent_api_key.dan_schema_registry.secret
  sensitive = true
}

output "dan_flink_api_key" {
  value     = confluent_api_key.dan_flink.id
  sensitive = true
}

output "dan_flink_api_secret" {
  value     = confluent_api_key.dan_flink.secret
  sensitive = true
}

# ---------------------------------------------------------------- Teresa's credentials

output "teresa_service_account_id" {
  value = confluent_service_account.teresa.id
}

output "teresa_kafka_api_key" {
  value     = confluent_api_key.teresa_kafka.id
  sensitive = true
}

output "teresa_kafka_api_secret" {
  value     = confluent_api_key.teresa_kafka.secret
  sensitive = true
}

output "teresa_tableflow_api_key" {
  value     = confluent_api_key.teresa_tableflow.id
  sensitive = true
}

output "teresa_tableflow_api_secret" {
  value     = confluent_api_key.teresa_tableflow.secret
  sensitive = true
}
