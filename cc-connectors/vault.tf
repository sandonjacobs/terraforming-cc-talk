data "vault_generic_secret" "confluent_environment" {
  path = "${var.vault_path}/confluent_environment"
}
data "vault_generic_secret" "cc_kafka" {
  path = "${var.vault_path}/kafka"
}

data "vault_generic_secret" "kafka_cluster_mgr" {
  path = "${var.vault_path}/kafka_cluster_mgr"
}

data "vault_generic_secret" "kafka_developer" {
  path = "${var.vault_path}/kafka_developer"
}

# data "vault_generic_secret" "cc_schema_registry" {
#   path = "${var.vault_path}/schema-registry"
# }
#
# data "vault_generic_secret" "flink_weather_compute" {
#   path = "${var.vault_path}/flink_weather_compute"
# }

locals {
  confluent_env = {
    id = data.vault_generic_secret.confluent_environment.data["id"]
    display_name = data.vault_generic_secret.confluent_environment.data["display_name"]
    org_id = data.vault_generic_secret.confluent_environment.data["org_id"]
    cloud_provider = data.vault_generic_secret.confluent_environment.data["cloud_provider"]
    cloud_region = data.vault_generic_secret.confluent_environment.data["cloud_region"]
  }

  kafka = {
    bootstrap_servers = data.vault_generic_secret.cc_kafka.data["bootstrap_servers"]
    rest_endpoint = data.vault_generic_secret.cc_kafka.data["rest_endpoint"]
    cluster_id = data.vault_generic_secret.cc_kafka.data["cluster_id"]
    cluster_name = data.vault_generic_secret.cc_kafka.data["cluster_name"]
    rbac_crn = data.vault_generic_secret.cc_kafka.data["rbac_crn"]
  }

  sa_kafka_cluster_mgr = {
    api_key_id = data.vault_generic_secret.kafka_cluster_mgr.data["api_key"]
    api_key_secret = data.vault_generic_secret.kafka_cluster_mgr.data["secret"]
  }


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

  kafka_developer = {
    svc_acct_id = data.vault_generic_secret.kafka_developer.data["svc_acct_id"]
    api_key_id = data.vault_generic_secret.kafka_developer.data["api_key_id"]
    api_key_secret = data.vault_generic_secret.kafka_developer.data["api_key_secret"]
  }

}