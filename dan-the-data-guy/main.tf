terraform {
  required_version = ">= 1.7"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.91.0"
    }
  }
}

# Dan uses only resource-scoped credentials: a Schema Registry key for schemas and a Flink key for
# statements, both passed on the resources themselves.
provider "confluent" {}
