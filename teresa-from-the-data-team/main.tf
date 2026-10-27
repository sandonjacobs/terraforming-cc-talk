terraform {
  required_version = ">= 1.7"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.91.0"
    }
  }
}

# Teresa uses only resource-scoped credentials: a Tableflow API key on the provider, and her Kafka
# API key passed on the resources themselves.
provider "confluent" {
  tableflow_api_key    = var.omar_teresa_tableflow_api_key
  tableflow_api_secret = var.omar_teresa_tableflow_api_secret
}
