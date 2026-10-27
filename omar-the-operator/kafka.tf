resource "confluent_kafka_cluster" "kafka_cluster" {
  display_name = var.cc_kafka_cluster_name
  availability = "SINGLE_ZONE"
  cloud        = var.cloud_provider
  region       = var.cloud_region

  # Standard is reachable over the public internet, so a laptop, managed connectors and Flink need
  # no private networking. Enterprise clusters require a PrivateLink access point instead.
  standard {}

  environment {
    id = confluent_environment.cc_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Advanced governance provisions Schema Registry for the environment; we look it up once the
# cluster exists because Schema Registry is created in the cluster's region.
data "confluent_schema_registry_cluster" "advanced" {
  environment {
    id = confluent_environment.cc_env.id
  }

  depends_on = [confluent_kafka_cluster.kafka_cluster]
}

# 'env-manager' administers the environment so Omar can set Schema Registry's compatibility
# policy, which Dan's schemas are validated against.
resource "confluent_service_account" "env_manager" {
  display_name = "${var.cc_kafka_cluster_name}-env-manager"
  description  = "Service account Omar uses to administer the environment and Schema Registry"
}

resource "confluent_role_binding" "env_manager_environment_admin" {
  principal   = "User:${confluent_service_account.env_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.cc_env.resource_name
}

resource "confluent_api_key" "env_manager_schema_registry" {
  display_name = "env-manager-schema-registry-api-key"
  description  = "Schema Registry API key owned by the env-manager service account"

  owner {
    id          = confluent_service_account.env_manager.id
    api_version = confluent_service_account.env_manager.api_version
    kind        = confluent_service_account.env_manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.advanced.id
    api_version = data.confluent_schema_registry_cluster.advanced.api_version
    kind        = data.confluent_schema_registry_cluster.advanced.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  # The key must not be used before the role binding exists, so every resource that uses it
  # inherits the ordering from this one depends_on instead of repeating it.
  depends_on = [
    confluent_role_binding.env_manager_environment_admin
  ]
}

resource "confluent_schema_registry_cluster_config" "compatibility" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.advanced.id
  }

  rest_endpoint       = data.confluent_schema_registry_cluster.advanced.rest_endpoint
  compatibility_level = "BACKWARD"

  credentials {
    key    = confluent_api_key.env_manager_schema_registry.id
    secret = confluent_api_key.env_manager_schema_registry.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
