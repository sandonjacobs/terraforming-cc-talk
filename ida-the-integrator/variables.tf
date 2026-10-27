# ---- Values published by Omar (loaded from .env by scripts/load-env.sh) ----

variable "omar_environment_id" {
  type        = string
  description = "Confluent Cloud environment ID"
}

variable "omar_kafka_cluster_id" {
  type        = string
  description = "Kafka cluster ID"
}

variable "omar_kafka_rest_endpoint" {
  type        = string
  description = "Kafka REST endpoint"
}

variable "omar_ida_kafka_api_key" {
  type        = string
  description = "Kafka API key issued to Ida"
  sensitive   = true
}

variable "omar_ida_kafka_api_secret" {
  type        = string
  description = "Kafka API secret issued to Ida"
  sensitive   = true
}

variable "omar_ida_cloud_api_key" {
  type        = string
  description = "Cloud API key issued to Ida for managing connectors"
  sensitive   = true
}

variable "omar_ida_cloud_api_secret" {
  type        = string
  description = "Cloud API secret issued to Ida for managing connectors"
  sensitive   = true
}

# ---- Datagen Orders ----

variable "orders_interval_ms" {
  type        = number
  description = "Delay between generated order records, in milliseconds"
  default     = 1000
}

# ---- Topic (hyphens only, and the landing- prefix Ida's access is scoped to) ----

variable "orders_topic_name" {
  type        = string
  description = "Landing topic for generated orders"
  default     = "landing-orders"

  validation {
    condition     = startswith(var.orders_topic_name, "landing-") && !strcontains(var.orders_topic_name, ".")
    error_message = "Topic names must start with 'landing-' and must not contain dots."
  }
}
