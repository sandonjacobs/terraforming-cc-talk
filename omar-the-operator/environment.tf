data "confluent_organization" "main" {}

resource "confluent_environment" "cc_env" {
  display_name = var.cc_env_display_name

  stream_governance {
    package = "ADVANCED"
  }

  lifecycle {
    prevent_destroy = false
  }
}
