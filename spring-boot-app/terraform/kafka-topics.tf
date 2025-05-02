resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = local.kafka_cluster_id
  }

  rest_endpoint = local.kafka_rest_endpoint

  topic_name    = "orders"
  partitions_count = 6
  config = {
    "cleanup.policy" = "delete"
    "retention.ms" = "604800000" # 7 days
  }
  credentials {
    key    = local.kafka_app_manager_api_key
    secret = local.kafka_app_manager_api_secret
  }

  lifecycle {
    prevent_destroy = false
  } 
}

resource "confluent_schema" "order-item" {
  subject_name = "order-item-ref"

  schema_registry_cluster {
    id = local.schema_registry_id
  }

  format = "AVRO"
  schema = file("${path.root}/../src/main/avro/order-item.avsc")

  credentials {
    key    = local.schema_registry_api_key
    secret = local.schema_registry_api_secret
  }

  rest_endpoint = local.schema_registry_endpoint

  lifecycle {
    prevent_destroy = false
  } 
}

resource "confluent_schema" "address" {
  subject_name = "address-ref"

  schema_registry_cluster {
    id = local.schema_registry_id
  }

  format = "AVRO"
  schema = file("${path.root}/../src/main/avro/address.avsc")

  credentials {
    key    = local.schema_registry_api_key
    secret = local.schema_registry_api_secret
  }

  rest_endpoint = local.schema_registry_endpoint

  lifecycle {
    prevent_destroy = false
  } 
}

resource "confluent_schema" "orders-value" {
  subject_name = "orders-value"

  schema_registry_cluster {
    id = local.schema_registry_id
  }

  format = "AVRO"
  schema = file("${path.root}/../src/main/avro/orders-value.avsc")
  schema_reference {
    name = "shipping_address"
    subject_name = confluent_schema.address.subject_name
    version = confluent_schema.address.version
  }
  schema_reference {
    name = "items"
    subject_name = confluent_schema.order-item.subject_name
    version = confluent_schema.order-item.version
  }

  credentials {
    key    = local.schema_registry_api_key
    secret = local.schema_registry_api_secret
  }

  rest_endpoint = local.schema_registry_endpoint

  depends_on = [ confluent_schema.order-item, confluent_schema.address ]

  lifecycle {
    prevent_destroy = false
  } 
}