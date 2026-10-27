# ---- Values published by Omar and Dan (loaded from .env by scripts/load-env.sh) ----

variable "omar_environment_id" {
  type        = string
  description = "Environment ID"
}

variable "omar_kafka_cluster_id" {
  type        = string
  description = "Kafka cluster ID"
}

variable "omar_kafka_rest_endpoint" {
  type        = string
  description = "Kafka REST endpoint"
}

variable "omar_teresa_kafka_api_key" {
  type        = string
  description = "Kafka API key issued to Teresa"
  sensitive   = true
}

variable "omar_teresa_kafka_api_secret" {
  type        = string
  description = "Kafka API secret issued to Teresa"
  sensitive   = true
}

variable "omar_teresa_tableflow_api_key" {
  type        = string
  description = "Tableflow API key issued to Teresa"
  sensitive   = true
}

variable "omar_teresa_tableflow_api_secret" {
  type        = string
  description = "Tableflow API secret issued to Teresa"
  sensitive   = true
}

variable "dan_curated_topics" {
  type        = string
  description = "Comma-separated curated topic names published by Dan"
}

# ---- The topic Teresa turns into a table (hyphens only, and the curated- prefix Dan's topics use) ----

variable "curated_orders_topic" {
  type        = string
  description = "Topic to enable Tableflow on; must match Dan's curated_orders_topic and Omar's Teresa role binding"
  default     = "curated-orders"

  validation {
    condition     = startswith(var.curated_orders_topic, "curated-") && !strcontains(var.curated_orders_topic, ".")
    error_message = "Topic names must start with 'curated-' and must not contain dots."
  }
}
