# resource "confluent_flink_compute_pool" "weather_compute_pool" {
#   display_name     = "weather_compute_pool"
#   cloud            = var.cloud_provider
#   region           = var.cloud_region
#   max_cfu          = 10
#   environment {
#     id = confluent_environment.cc_env.id
#   }
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# data "confluent_flink_compute_pool" "weather_compute_pool" {
#   id = confluent_flink_compute_pool.weather_compute_pool.id
#   environment {
#     id = confluent_environment.cc_env.id
#   }
# }
#
# data "confluent_flink_region" "weather_compute_pool" {
#   cloud = confluent_flink_compute_pool.weather_compute_pool.cloud
#   region = confluent_flink_compute_pool.weather_compute_pool.region
# }