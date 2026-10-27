terraform {
  required_version = ">= 1.17.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.91.0"
    }
  }
}

# Organization-level credentials come from the shell, never from the repo:
#   export CONFLUENT_CLOUD_API_KEY=...
#   export CONFLUENT_CLOUD_API_SECRET=...
# Do not set organization_id here: the provider only accepts it together with the six Flink
# settings, which Omar does not use. Dan's provider block sets all seven.
provider "confluent" {}
