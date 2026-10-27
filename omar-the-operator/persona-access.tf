# Omar creates one service account per downstream persona, grants it only the roles its job needs,
# and issues the API keys it will use. Access is scoped by topic-name prefix:
#   landing-*  owned by Ida, curated-*  owned by Dan, app-*  owned by Ali.

locals {
  kafka_crn = "${confluent_kafka_cluster.kafka_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.kafka_cluster.id}"
  sr_crn    = data.confluent_schema_registry_cluster.advanced.resource_name

  ali_bindings = {
    topic_manage = { role = "DeveloperManage", crn = "${local.kafka_crn}/topic=app-*" }
    topic_write  = { role = "DeveloperWrite", crn = "${local.kafka_crn}/topic=app-*" }
    subject_read = { role = "DeveloperRead", crn = "${local.sr_crn}/subject=app-*" }
  }

  # Teresa can enable Tableflow only on the one topic she is meant to publish as a table.
  # VERIFY at the first live apply (research.md item 14b): that a ResourceOwner binding on a topic
  # that does not exist yet (Dan creates curated-orders later) is accepted. If it is rejected,
  # do NOT widen this to topic=curated-*: that would let Teresa enable Tableflow on every curated
  # topic and break Principle IV and SC-009. Move the binding to run after Dan instead.
  teresa_bindings = {
    topic_owner = { role = "ResourceOwner", crn = "${local.kafka_crn}/topic=curated-orders" }
    # Tableflow reads the topic's schema, so it needs read on all subjects (Confluent's Tableflow
    # RBAC page). Managed storage needs neither Assigner nor CloudClusterAdmin.
    subject_read = { role = "DeveloperRead", crn = "${local.sr_crn}/subject=*" }
  }

  dan_bindings = {
    read_landing_topics   = { role = "DeveloperRead", crn = "${local.kafka_crn}/topic=landing-*" }
    read_app_topics       = { role = "DeveloperRead", crn = "${local.kafka_crn}/topic=app-*" }
    curated_topics_read   = { role = "DeveloperRead", crn = "${local.kafka_crn}/topic=curated-*" }
    curated_topics_write  = { role = "DeveloperWrite", crn = "${local.kafka_crn}/topic=curated-*" }
    curated_topics_manage = { role = "DeveloperManage", crn = "${local.kafka_crn}/topic=curated-*" }
    read_landing_subjects = { role = "DeveloperRead", crn = "${local.sr_crn}/subject=landing-*" }
    write_app_subjects    = { role = "DeveloperWrite", crn = "${local.sr_crn}/subject=app-*" }
    # Dan's schema is hard-deleted on destroy, which DeveloperWrite does not allow.
    manage_app_subjects    = { role = "DeveloperManage", crn = "${local.sr_crn}/subject=app-*" }
    write_curated_subjects = { role = "DeveloperWrite", crn = "${local.sr_crn}/subject=curated-*" }
    flink_developer        = { role = "FlinkDeveloper", crn = confluent_environment.cc_env.resource_name }
    # Flink statements write with transactions, which need this transactional-id grant.
    flink_transactional_ids = { role = "DeveloperWrite", crn = "${local.kafka_crn}/transactional-id=_confluent-flink_*" }
  }
}

# ---------------------------------------------------------------- Ida the Integrator

resource "confluent_service_account" "ida" {
  display_name = "${var.cc_kafka_cluster_name}-ida"
  description  = "Ida the Integrator: manages managed connectors and the landing-* topics"
}

# TRADE-OFF: managing connectors through the Confluent Cloud API needs more than topic-level
# access, and CloudClusterAdmin on the cluster is the role known to work. A narrower role should
# replace it if one is confirmed; see ida-the-integrator/README.md.
resource "confluent_role_binding" "ida_cluster_admin" {
  principal   = "User:${confluent_service_account.ida.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn
}

# The Datagen connector registers the Avro schema for its landing topic, so Ida needs to write
# landing-* subjects.
resource "confluent_role_binding" "ida_landing_subjects" {
  principal   = "User:${confluent_service_account.ida.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.sr_crn}/subject=landing-*"
}

resource "confluent_api_key" "ida_kafka" {
  display_name = "ida-kafka-api-key"
  description  = "Kafka API key owned by Ida's service account"

  owner {
    id          = confluent_service_account.ida.id
    api_version = confluent_service_account.ida.api_version
    kind        = confluent_service_account.ida.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.ida_cluster_admin]
}

# A Cloud API key (no managed_resource) lets Ida's workspace manage connectors.
resource "confluent_api_key" "ida_cloud" {
  display_name = "ida-cloud-api-key"
  description  = "Cloud API key owned by Ida's service account, used to manage connectors"

  owner {
    id          = confluent_service_account.ida.id
    api_version = confluent_service_account.ida.api_version
    kind        = confluent_service_account.ida.kind
  }

  depends_on = [confluent_role_binding.ida_cluster_admin]
}

# ---------------------------------------------------------------- Ali the App Developer

resource "confluent_service_account" "ali" {
  display_name = "${var.cc_kafka_cluster_name}-ali"
  description  = "Ali the App Developer: owns the app-* topics and produces application events"
}

resource "confluent_role_binding" "ali" {
  for_each = local.ali_bindings

  principal   = "User:${confluent_service_account.ali.id}"
  role_name   = each.value.role
  crn_pattern = each.value.crn
}

resource "confluent_api_key" "ali_kafka" {
  display_name = "ali-kafka-api-key"
  description  = "Kafka API key owned by Ali's service account"

  owner {
    id          = confluent_service_account.ali.id
    api_version = confluent_service_account.ali.api_version
    kind        = confluent_service_account.ali.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.ali]
}

resource "confluent_api_key" "ali_schema_registry" {
  display_name = "ali-schema-registry-api-key"
  description  = "Schema Registry API key owned by Ali's service account (read-only on app-* subjects)"

  owner {
    id          = confluent_service_account.ali.id
    api_version = confluent_service_account.ali.api_version
    kind        = confluent_service_account.ali.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.advanced.id
    api_version = data.confluent_schema_registry_cluster.advanced.api_version
    kind        = data.confluent_schema_registry_cluster.advanced.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.ali]
}

# ---------------------------------------------------------------- Dan the Data Guy

resource "confluent_service_account" "dan" {
  display_name = "${var.cc_kafka_cluster_name}-dan"
  description  = "Dan the Data Guy: registers schemas and runs Flink SQL, owns the curated-* topics"
}

resource "confluent_role_binding" "dan" {
  for_each = local.dan_bindings

  principal   = "User:${confluent_service_account.dan.id}"
  role_name   = each.value.role
  crn_pattern = each.value.crn
}

# Lets Dan's Flink statements run under his own service account.
resource "confluent_role_binding" "dan_assigner" {
  principal   = "User:${confluent_service_account.dan.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.main.resource_name}/service-account=${confluent_service_account.dan.id}"
}

resource "confluent_api_key" "dan_kafka" {
  display_name = "dan-kafka-api-key"
  description  = "Kafka API key owned by Dan's service account"

  owner {
    id          = confluent_service_account.dan.id
    api_version = confluent_service_account.dan.api_version
    kind        = confluent_service_account.dan.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.dan]
}

resource "confluent_api_key" "dan_schema_registry" {
  display_name = "dan-schema-registry-api-key"
  description  = "Schema Registry API key owned by Dan's service account"

  owner {
    id          = confluent_service_account.dan.id
    api_version = confluent_service_account.dan.api_version
    kind        = confluent_service_account.dan.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.advanced.id
    api_version = data.confluent_schema_registry_cluster.advanced.api_version
    kind        = data.confluent_schema_registry_cluster.advanced.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.dan]
}

resource "confluent_api_key" "dan_flink" {
  display_name = "dan-flink-api-key"
  description  = "Flink API key owned by Dan's service account"

  owner {
    id          = confluent_service_account.dan.id
    api_version = confluent_service_account.dan.api_version
    kind        = confluent_service_account.dan.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.region.id
    api_version = data.confluent_flink_region.region.api_version
    kind        = data.confluent_flink_region.region.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.dan, confluent_role_binding.dan_assigner]
}

# ---------------------------------------------------------------- Teresa from the data team

resource "confluent_service_account" "teresa" {
  display_name = "${var.cc_kafka_cluster_name}-teresa"
  description  = "Teresa from the data team: enables Tableflow on curated-orders"
}

# The binding names curated-orders exactly, so it must match Dan's curated_orders_topic. If Dan
# renames that topic, change teresa_bindings above as well.
resource "confluent_role_binding" "teresa" {
  for_each = local.teresa_bindings

  principal   = "User:${confluent_service_account.teresa.id}"
  role_name   = each.value.role
  crn_pattern = each.value.crn
}

# Used for the confluent_tableflow_topic credentials block and the topic-exists check.
resource "confluent_api_key" "teresa_kafka" {
  display_name = "teresa-kafka-api-key"
  description  = "Kafka API key owned by Teresa's service account"

  owner {
    id          = confluent_service_account.teresa.id
    api_version = confluent_service_account.teresa.api_version
    kind        = confluent_service_account.teresa.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.teresa]
}

# The provider-level credential for the Tableflow API. VERIFY (research.md item 14a): the
# managed_resource values below (id "tableflow", api_version "tableflow/v1", kind "Tableflow")
# against the provider docs at the first live apply.
resource "confluent_api_key" "teresa_tableflow" {
  display_name = "teresa-tableflow-api-key"
  description  = "Tableflow API key owned by Teresa's service account"

  owner {
    id          = confluent_service_account.teresa.id
    api_version = confluent_service_account.teresa.api_version
    kind        = confluent_service_account.teresa.kind
  }

  managed_resource {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  depends_on = [confluent_role_binding.teresa]
}
