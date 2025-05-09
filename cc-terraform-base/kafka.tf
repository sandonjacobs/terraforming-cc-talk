# Update the config to use a cloud provider and region of your choice.
# https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_kafka_cluster
resource "confluent_kafka_cluster" "kafka_cluster" {
  display_name = var.cc_kafka_cluster_name
  availability = "SINGLE_ZONE"
  cloud        = var.cloud_provider
  region       = var.cloud_region
  standard  {}
  environment {
    id = confluent_environment.cc_env.id
  }

  depends_on = [confluent_environment.cc_env]
}

data "confluent_schema_registry_cluster" "advanced" {
  environment {
    id = confluent_environment.cc_env.id
  }
  depends_on = [confluent_kafka_cluster.kafka_cluster]
}

resource "confluent_schema_registry_cluster_config" "schema_registry_cluster_config" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.advanced.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.advanced.rest_endpoint
  compatibility_level = "BACKWARD"
  credentials {
    key    = confluent_api_key.sr-manager-api-key.id
    secret = confluent_api_key.sr-manager-api-key.secret
  }

  depends_on = [data.confluent_schema_registry_cluster.advanced]

  lifecycle {
    prevent_destroy = false
  }
}


// Kafka Connect Service Account

// Flink Developer Service Account

#
#
# resource "confluent_service_account" "env-manager" {
#   display_name = "${var.cc_kafka_cluster_name}-env-manager"
#   description  = "Service account to manage 'Staging' environment"
# }
#
# resource "confluent_role_binding" "env-manager-environment-admin" {
#   principal   = "User:${confluent_service_account.env-manager.id}"
#   role_name   = "EnvironmentAdmin"
#   crn_pattern = confluent_environment.cc_env.resource_name
# }
#
# resource "confluent_api_key" "env-manager-schema-registry-api-key" {
#   display_name = "env-manager-schema-registry-api-key"
#   description  = "Schema Registry API Key that is owned by 'env-manager' service account"
#   owner {
#     id          = confluent_service_account.env-manager.id
#     api_version = confluent_service_account.env-manager.api_version
#     kind        = confluent_service_account.env-manager.kind
#   }
#
#   managed_resource {
#     id          = data.confluent_schema_registry_cluster.advanced.id
#     api_version = data.confluent_schema_registry_cluster.advanced.api_version
#     kind        = data.confluent_schema_registry_cluster.advanced.kind
#
#     environment {
#       id = confluent_environment.cc_env.id
#     }
#   }
#
#   # The goal is to ensure that confluent_role_binding.env-manager-environment-admin is created before
#   # confluent_api_key.env-manager-schema-registry-api-key is used to create instances of
#   # confluent_schema resources.
#
#   # 'depends_on' meta-argument is specified in confluent_api_key.env-manager-schema-registry-api-key to avoid having
#   # multiple copies of this definition in the configuration which would happen if we specify it in
#   # confluent_schema resources instead.
#   depends_on = [
#     confluent_role_binding.env-manager-environment-admin,
#     data.confluent_schema_registry_cluster.advanced
#   ]
# }
#
