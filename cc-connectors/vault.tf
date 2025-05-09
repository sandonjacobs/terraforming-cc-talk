data "vault_generic_secret" "confluent_environment" {
  path = "${var.vault_path}/confluent_environment"
}
data "vault_generic_secret" "cc_kafka" {
  path = "${var.vault_path}/kafka"
}

data "vault_generic_secret" "sa_kafka_manager" {
  path = "${var.vault_path}/sa_kafka_manager"
}


# data "vault_generic_secret" "flink_developer" {
#   path = "${var.vault_path}/flink_developer"
# }
#

data "vault_generic_secret" "cc_schema_registry" {
  path = "${var.vault_path}/schema-registry"
}

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

  schema_registry = {
    endpoint = data.vault_generic_secret.cc_schema_registry.data["endpoint"]
    id = data.vault_generic_secret.cc_schema_registry.data["id"]
  }

  sa_kafka_manager = {
    api_key_id = data.vault_generic_secret.sa_kafka_manager.data["api_key"]
    api_key_secret = data.vault_generic_secret.sa_kafka_manager.data["secret"]
  }



  # kafka_developer = {
  #   svc_acct_id = data.vault_generic_secret.kafka_developer.data["svc_acct_id"]
  #   api_key_id = data.vault_generic_secret.kafka_developer.data["api_key_id"]
  #   api_key_secret = data.vault_generic_secret.kafka_developer.data["api_key_secret"]
  # }

  # flink_developer = {
  #   svc_acct_id = data.vault_generic_secret.flink_developer.data["svc_acct_id"]
  #   api_key_id = data.vault_generic_secret.flink_developer.data["api_key_id"]
  #   api_key_secret = data.vault_generic_secret.flink_developer.data["api_key_secret"]
  # }

  # flink_weather_compute = {
  #   id = data.vault_generic_secret.flink_weather_compute.data["pool_id"]
  #   name = data.vault_generic_secret.flink_weather_compute.data["pool_name"]
  #   rest_endpoint = data.vault_generic_secret.flink_weather_compute.data["region_rest_endpoint"]
  # }
}