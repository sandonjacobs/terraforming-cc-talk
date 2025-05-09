
resource "confluent_service_account" "sr-manager" {
  display_name = "${var.cc_kafka_cluster_name}-sr-manager"
  description  = "Service account to manage 'Staging' environment"
}

resource "confluent_role_binding" "sr-manager-environment-admin" {
  principal   = "User:${confluent_service_account.sr-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.cc_env.resource_name
}

resource "confluent_api_key" "sr-manager-api-key" {
  display_name = "sr-manager-api-key"
  description  = "Schema Registry API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.sr-manager.id
    api_version = confluent_service_account.sr-manager.api_version
    kind        = confluent_service_account.sr-manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.advanced.id
    api_version = data.confluent_schema_registry_cluster.advanced.api_version
    kind        = data.confluent_schema_registry_cluster.advanced.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  # The goal is to ensure that confluent_role_binding.env-manager-environment-admin is created before
  # confluent_api_key.env-manager-schema-registry-api-key is used to create instances of
  # confluent_schema resources.

  # 'depends_on' meta-argument is specified in confluent_api_key.env-manager-schema-registry-api-key to avoid having
  # multiple copies of this definition in the configuration which would happen if we specify it in
  # confluent_schema resources instead.
  depends_on = [
    confluent_role_binding.sr-manager-environment-admin,
    data.confluent_schema_registry_cluster.advanced
  ]
}
