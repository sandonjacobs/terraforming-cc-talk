# Offline wiring checks with a mocked provider; nothing here talks to Confluent Cloud.

variables {
  organization_id = "00000000-0000-0000-0000-000000000001"
}

mock_provider "confluent" {
  # The provider validates CRN formats, so the mocked parents must return CRN-shaped values.
  mock_resource "confluent_environment" {
    defaults = {
      resource_name = "crn://confluent.cloud/organization=org-1/environment=env-1"
    }
  }

  mock_resource "confluent_kafka_cluster" {
    defaults = {
      rbac_crn    = "crn://confluent.cloud/organization=org-1/environment=env-1/cloud-cluster=lkc-1"
      api_version = "cmk/v2"
      kind        = "Cluster"
    }
  }

  mock_resource "confluent_service_account" {
    defaults = {
      id          = "sa-mock01"
      api_version = "iam/v2"
      kind        = "ServiceAccount"
    }
  }

  mock_data "confluent_flink_region" {
    defaults = {
      api_version = "fcpm/v2"
      kind        = "Region"
    }
  }

  mock_data "confluent_organization" {
    defaults = {
      resource_name = "crn://confluent.cloud/organization=org-1"
    }
  }

  mock_data "confluent_schema_registry_cluster" {
    defaults = {
      resource_name = "crn://confluent.cloud/organization=org-1/environment=env-1/schema-registry=lsrc-1"
      rest_endpoint = "https://psrc-mock.us-east-1.aws.confluent.cloud"
      api_version   = "srcm/v3"
      kind          = "Cluster"
    }
  }
}

run "platform_matches_the_spec" {
  command = apply

  assert {
    condition     = confluent_environment.cc_env.stream_governance[0].package == "ADVANCED"
    error_message = "Environment must use the ADVANCED governance package"
  }

  assert {
    condition     = length(confluent_kafka_cluster.kafka_cluster.standard) == 1
    error_message = "Kafka cluster must be Standard"
  }

  assert {
    condition     = confluent_kafka_cluster.kafka_cluster.cloud == "AWS" && confluent_kafka_cluster.kafka_cluster.region == "us-east-2"
    error_message = "Kafka cluster must be in AWS us-east-1"
  }

  assert {
    condition     = confluent_flink_compute_pool.pool.cloud == "AWS" && confluent_flink_compute_pool.pool.region == "us-east-2"
    error_message = "Flink compute pool must be in AWS us-east-1"
  }

  assert {
    condition     = confluent_schema_registry_cluster_config.compatibility.compatibility_level == "BACKWARD"
    error_message = "Schema Registry compatibility must be BACKWARD"
  }
}

run "outputs_cover_the_env_contract" {
  command = apply

  assert {
    condition = alltrue([
      output.organization_id == "00000000-0000-0000-0000-000000000001",
      length(output.environment_id) > 0,
      length(output.environment_name) > 0,
      output.cloud_region == "us-east-2",
      length(output.kafka_cluster_id) > 0,
      length(output.kafka_cluster_name) > 0,
      length(output.kafka_bootstrap_endpoint) > 0,
      length(output.kafka_rest_endpoint) > 0,
      length(output.schema_registry_id) > 0,
      length(output.schema_registry_rest_endpoint) > 0,
      length(output.flink_compute_pool_id) > 0,
      length(output.flink_rest_endpoint) > 0,
    ])
    error_message = "A platform output from the env-file contract is missing or empty"
  }

  assert {
    condition = alltrue([
      length(output.ida_service_account_id) > 0,
      length(nonsensitive(output.ida_kafka_api_key)) > 0,
      length(nonsensitive(output.ida_kafka_api_secret)) > 0,
      length(nonsensitive(output.ida_cloud_api_key)) > 0,
      length(nonsensitive(output.ida_cloud_api_secret)) > 0,
    ])
    error_message = "An Ida credential output from the env-file contract is missing or empty"
  }

  assert {
    condition = alltrue([
      length(output.ali_service_account_id) > 0,
      length(nonsensitive(output.ali_kafka_api_key)) > 0,
      length(nonsensitive(output.ali_kafka_api_secret)) > 0,
      length(nonsensitive(output.ali_schema_registry_api_key)) > 0,
      length(nonsensitive(output.ali_schema_registry_api_secret)) > 0,
    ])
    error_message = "An Ali credential output from the env-file contract is missing or empty"
  }

  assert {
    condition = alltrue([
      length(output.dan_service_account_id) > 0,
      length(nonsensitive(output.dan_kafka_api_key)) > 0,
      length(nonsensitive(output.dan_kafka_api_secret)) > 0,
      length(nonsensitive(output.dan_schema_registry_api_key)) > 0,
      length(nonsensitive(output.dan_schema_registry_api_secret)) > 0,
      length(nonsensitive(output.dan_flink_api_key)) > 0,
      length(nonsensitive(output.dan_flink_api_secret)) > 0,
    ])
    error_message = "A Dan credential output from the env-file contract is missing or empty"
  }

  assert {
    condition = alltrue([
      length(output.teresa_service_account_id) > 0,
      length(nonsensitive(output.teresa_kafka_api_key)) > 0,
      length(nonsensitive(output.teresa_kafka_api_secret)) > 0,
      length(nonsensitive(output.teresa_tableflow_api_key)) > 0,
      length(nonsensitive(output.teresa_tableflow_api_secret)) > 0,
    ])
    error_message = "A Teresa credential output from the env-file contract is missing or empty"
  }
}

run "topic_prefixes_use_hyphens_not_dots" {
  command = apply

  assert {
    condition     = alltrue([for b in values(local.ali_bindings) : !strcontains(split("=", b.crn)[length(split("=", b.crn)) - 1], ".")])
    error_message = "Ali's role-binding patterns must not use dotted names"
  }

  assert {
    condition     = alltrue([for b in values(local.dan_bindings) : !strcontains(split("=", b.crn)[length(split("=", b.crn)) - 1], ".")])
    error_message = "Dan's role-binding patterns must not use dotted names"
  }
}

run "teresa_is_scoped_to_curated_orders_only" {
  command = apply

  assert {
    condition = (
      local.teresa_bindings.topic_owner.role == "ResourceOwner" &&
      endswith(local.teresa_bindings.topic_owner.crn, "/topic=curated-orders")
    )
    error_message = "Teresa's topic binding must be ResourceOwner on exactly curated-orders"
  }

  assert {
    condition = alltrue([
      for b in values(local.teresa_bindings) :
      !endswith(b.crn, "topic=curated-*") && !endswith(b.crn, "topic=*")
    ])
    error_message = "Teresa must not hold a prefix or wildcard topic binding (SC-009)"
  }

  assert {
    condition     = alltrue([for b in values(local.teresa_bindings) : b.role != "CloudClusterAdmin" && b.role != "Assigner"])
    error_message = "Managed storage needs neither CloudClusterAdmin nor Assigner for Teresa"
  }
}
