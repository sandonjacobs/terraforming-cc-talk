terraform {
  required_version = ">= 1.7"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.91.0"
    }
  }
}

# Ali only touches Kafka topics, so no Cloud API key is needed: his Kafka API key is passed on
# the topic resource.
provider "confluent" {}
