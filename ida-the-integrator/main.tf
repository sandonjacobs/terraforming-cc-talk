terraform {
  required_version = ">= 1.7"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.91.0"
    }
  }
}

# Connectors are managed through the Confluent Cloud API, so Ida's workspace needs the Cloud API
# key Omar issued to her service account. Topics use her Kafka API key, set on each resource.
provider "confluent" {
  cloud_api_key    = var.omar_ida_cloud_api_key
  cloud_api_secret = var.omar_ida_cloud_api_secret
}
