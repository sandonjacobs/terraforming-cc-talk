resource "confluent_flink_compute_pool" "weather_compute_pool" {
  display_name     = "weather_compute_pool"
  cloud            = var.cloud_provider
  region           = var.cloud_region
  max_cfu          = 10
  environment {
    id = confluent_environment.cc_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "confluent_flink_compute_pool" "weather_compute_pool" {
  id = confluent_flink_compute_pool.weather_compute_pool.id
  environment {
    id = confluent_environment.cc_env.id
  }

  depends_on = [
    confluent_role_binding.flink-statements-runner-environment-admin,
    confluent_role_binding.kafka-manager-assigner,
    confluent_role_binding.kafka-manager-flink-developer,
    confluent_api_key.kafka-manager-flink-api-key,
  ]
}

data "confluent_flink_region" "weather_compute_pool" {
  cloud = confluent_flink_compute_pool.weather_compute_pool.cloud
  region = confluent_flink_compute_pool.weather_compute_pool.region
}

// Service account to perform a task within Confluent Cloud, such as executing a Flink statement
resource "confluent_service_account" "flink-statements-runner" {
  display_name = "${var.cc_env_display_name}-flink-statements-runner"
  description  = "Service account for running Flink Statements in 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "flink-statements-runner-environment-admin" {
  principal   = "User:${confluent_service_account.flink-statements-runner.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = data.confluent_environment.cc_env.resource_name
}

// https://docs.confluent.io/cloud/current/access-management/access-control/rbac/predefined-rbac-roles.html#flinkdeveloper
resource "confluent_role_binding" "kafka-manager-flink-developer" {
  principal   = "User:${confluent_service_account.kafka-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = data.confluent_environment.cc_env.resource_name
}

resource "confluent_role_binding" "flink-statements-runner-flink-developer" {
  principal   = "User:${confluent_service_account.flink-statements-runner.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = data.confluent_environment.cc_env.resource_name
}


// Note: these role bindings (app-manager-transaction-id-developer-read, app-manager-transaction-id-developer-write)
// are not required for running this example, but you may have to add it in order
// to create and complete transactions.
// https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html#authorization
resource "confluent_role_binding" "kafka-manager-transaction-id-developer-read" {
  principal   = "User:${confluent_service_account.kafka-manager.id}"
  role_name = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.kafka_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.kafka_cluster.id}/transactional-id=_confluent-flink_*"
}

resource "confluent_role_binding" "kafka-manager-transaction-id-developer-write" {
  principal   = "User:${confluent_service_account.kafka-manager.id}"
  role_name = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.kafka_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.kafka_cluster.id}/transactional-id=_confluent-flink_*"
}

// https://docs.confluent.io/cloud/current/access-management/access-control/rbac/predefined-rbac-roles.html#assigner
// https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html#submit-long-running-statements
resource "confluent_role_binding" "kafka-manager-assigner" {
  principal   = "User:${confluent_service_account.kafka-manager.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.cc_org.resource_name}/service-account=${confluent_service_account.flink-statements-runner.id}"
}

resource "confluent_api_key" "kafka-manager-flink-api-key" {
  display_name = "kafka-manager-flink-api-key"
  description  = "Flink API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.kafka-manager.id
    api_version = confluent_service_account.kafka-manager.api_version
    kind        = confluent_service_account.kafka-manager.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.weather_compute_pool.id
    api_version = data.confluent_flink_region.weather_compute_pool.api_version
    kind        = data.confluent_flink_region.weather_compute_pool.kind
    environment {
      id = data.confluent_environment.cc_env.id
    }
  }

  depends_on = [
    confluent_role_binding.kafka-manager-flink-developer,
    confluent_role_binding.kafka-manager-transaction-id-developer-read,
    confluent_role_binding.kafka-manager-transaction-id-developer-write
  ]
}
