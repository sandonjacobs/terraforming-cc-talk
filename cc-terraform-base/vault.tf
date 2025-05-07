resource "vault_generic_secret" "cc_environment" {
  path = "${var.vault_path}/confluent_environment"

  data_json = jsonencode({
    id = confluent_environment.cc_env.id
    org_id = var.org_id
    display_name = confluent_environment.cc_env.display_name
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
    bootstrap_servers = confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint
    cluster_id = confluent_kafka_cluster.kafka_cluster.id
    cluster_name = confluent_kafka_cluster.kafka_cluster.display_name
    rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
    rbac_crn = confluent_kafka_cluster.kafka_cluster.rbac_crn
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

resource "vault_generic_secret" "kafka_developer" {
  path      = "${var.vault_path}/kafka_developer"
  data_json = jsonencode({
    svc_acct_id = confluent_service_account.kafka-developer.id
    api_key_id = confluent_api_key.kafka-developer.id
    api_key_secret = confluent_api_key.kafka-developer.secret
  })

  lifecycle {
    prevent_destroy = false
  }
}

resource "vault_generic_secret" "flink_developer" {
  path      = "${var.vault_path}/flink_developer"
  data_json = jsonencode({
    svc_acct_id = confluent_service_account.flink-developer.id
    api_key_id = confluent_api_key.flink-developer.id
    api_key_secret = confluent_api_key.flink-developer.secret
  })

  lifecycle {
    prevent_destroy = false
  }
}

resource "vault_generic_secret" "schema_registry" {

  path = "${var.vault_path}/schema-registry"

  data_json = jsonencode({
    endpoint = data.confluent_schema_registry_cluster.advanced.rest_endpoint
    id = data.confluent_schema_registry_cluster.advanced.id
    # schema_registry_api_key = confluent_api_key.env-manager-schema-registry-api-key.id
    # schema_registry_api_secret = confluent_api_key.env-manager-schema-registry-api-key.secret
  })

  depends_on = [
    data.confluent_schema_registry_cluster.advanced
  ]

  lifecycle {
    prevent_destroy = false
  }
}

resource "vault_generic_secret" "flink_weather_compute" {

  path = "${var.vault_path}/flink_weather_compute"

  data_json = jsonencode({
    pool_id = confluent_flink_compute_pool.weather_compute_pool.id
    pool_name = confluent_flink_compute_pool.weather_compute_pool.display_name
    region_rest_endpoint = data.confluent_flink_region.weather_compute_pool.region
  })

  lifecycle {
    prevent_destroy = false
  }
}
