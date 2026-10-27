resource "confluent_flink_compute_pool" "pool" {
  display_name = "${var.cc_env_display_name}-flink-pool"
  cloud        = var.cloud_provider
  region       = var.cloud_region
  max_cfu      = var.flink_max_cfu

  environment {
    id = confluent_environment.cc_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Provides the regional Flink REST endpoint that Dan's statements are submitted to.
data "confluent_flink_region" "region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
}
