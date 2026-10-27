# ---- Values published by Omar (loaded from .env by scripts/load-env.sh) ----

variable "omar_organization_id" {
  type        = string
  description = "Confluent Cloud organization ID"
}

variable "omar_environment_id" {
  type        = string
  description = "Environment ID (also the Flink catalog's environment)"
}

variable "omar_environment_name" {
  type        = string
  description = "Environment display name; Flink's current catalog"
}

variable "omar_kafka_cluster_name" {
  type        = string
  description = "Kafka cluster display name; Flink's current database"
}

variable "omar_schema_registry_id" {
  type        = string
  description = "Schema Registry cluster ID"
}

variable "omar_schema_registry_rest_endpoint" {
  type        = string
  description = "Schema Registry REST endpoint"
}

variable "omar_flink_compute_pool_id" {
  type        = string
  description = "Flink compute pool ID"
}

variable "omar_flink_rest_endpoint" {
  type        = string
  description = "Flink REST endpoint"
}

variable "omar_dan_service_account_id" {
  type        = string
  description = "Dan's service account ID; Flink statements run as this principal"
}

variable "omar_dan_schema_registry_api_key" {
  type        = string
  description = "Schema Registry API key issued to Dan"
  sensitive   = true
}

variable "omar_dan_schema_registry_api_secret" {
  type        = string
  description = "Schema Registry API secret issued to Dan"
  sensitive   = true
}

variable "omar_dan_flink_api_key" {
  type        = string
  description = "Flink API key issued to Dan"
  sensitive   = true
}

variable "omar_dan_flink_api_secret" {
  type        = string
  description = "Flink API secret issued to Dan"
  sensitive   = true
}

# ---- Values published by Ida and Ali ----

variable "ida_orders_topic" {
  type        = string
  description = "Landing topic for generated orders"
}

variable "ali_events_topic" {
  type        = string
  description = "Topic Ali's microservice produces events to"
}

# ---- Dan's output topic (hyphens only, and the curated- prefix Dan's access is scoped to) ----

variable "curated_orders_topic" {
  type        = string
  description = "Curated topic for flattened orders"
  default     = "curated-orders"

  validation {
    condition     = startswith(var.curated_orders_topic, "curated-") && !strcontains(var.curated_orders_topic, ".")
    error_message = "Topic names must start with 'curated-' and must not contain dots."
  }
}
