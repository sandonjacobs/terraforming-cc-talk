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
#
# // https://docs.confluent.io/cloud/current/access-management/access-control/rbac/predefined-rbac-roles.html#flinkadmin
# resource "confluent_role_binding" "app-manager-flink-developer" {
#   principal   = "User:${confluent_service_account.app-manager.id}"
#   role_name   = "FlinkAdmin"
#   crn_pattern = confluent_environment.cc_env.resource_name
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# data "confluent_organization" "main" {}
#
# data "confluent_flink_region" "main" {
#   cloud  = var.cloud_provider
#   region = var.cloud_region
# }
#
#
# resource "confluent_api_key" "app-manager-flink-api-key" {
#   display_name = "app-manager-flink-api-key"
#   description  = "Flink API Key that is owned by 'app-manager' service account"
#   owner {
#     id          = confluent_service_account.app-manager.id
#     api_version = confluent_service_account.app-manager.api_version
#     kind        = confluent_service_account.app-manager.kind
#   }
#   managed_resource {
#     id          = data.confluent_flink_region.main.id
#     api_version = confluent_flink_compute_pool.weather_compute_pool.api_version
#     kind        = data.confluent_flink_region.main.kind
#     environment {
#       id = confluent_environment.cc_env.id
#     }
#   }
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# // Service account to perform a task within Confluent Cloud, such as executing a Flink statement
# resource "confluent_service_account" "statements-runner" {
#   display_name = "${var.cc_env_display_name}-statements-runner"
#   description  = "Service account for running Flink Statements in 'inventory' Kafka cluster"
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# resource "confluent_api_key" "flink-statements-runner" {
#   display_name = "flink-statements-runner"
#   description = "statements runner api key"
#
#   owner {
#     id          = confluent_service_account.statements-runner.id
#     api_version = confluent_service_account.statements-runner.api_version
#     kind        = confluent_service_account.statements-runner.kind
#   }
#
#   managed_resource {
#     id          = data.confluent_flink_region.main.id
#     api_version = data.confluent_flink_region.main.api_version
#     kind        = data.confluent_flink_region.main.kind
#     environment {
#       id = confluent_environment.cc_env.id
#     }
#   }
#
#   lifecycle {
#     prevent_destroy = false
#   }
#
# }
#
# // https://docs.confluent.io/cloud/current/access-management/access-control/rbac/predefined-rbac-roles.html#assigner
# // https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html#submit-long-running-statements
#
# resource "confluent_role_binding" "statements-runner-flink-admin" {
#   principal   = "User:${confluent_service_account.statements-runner.id}"
#   role_name   = "FlinkAdmin"
#   crn_pattern = confluent_environment.cc_env.resource_name
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# resource "confluent_role_binding" "statements-runner-assigner" {
#   principal   = "User:${confluent_service_account.statements-runner.id}"
#   role_name   = "Assigner"
#   crn_pattern = "${data.confluent_organization.main.resource_name}/service-account=${confluent_service_account.statements-runner.id}"
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# resource "confluent_role_binding" "statements-runner-data-steward" {
#   principal   = "User:${confluent_service_account.statements-runner.id}"
#   role_name   = "DataSteward"
#   crn_pattern = confluent_environment.cc_env.resource_name
#   lifecycle {
#     prevent_destroy = false
#   }
# }
