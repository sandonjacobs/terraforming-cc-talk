# ---- Values published by Omar (loaded from .env by scripts/load-env.sh) ----

variable "omar_kafka_cluster_id" {
  type        = string
  description = "Kafka cluster ID"
}

variable "omar_kafka_rest_endpoint" {
  type        = string
  description = "Kafka REST endpoint"
}

variable "omar_ali_kafka_api_key" {
  type        = string
  description = "Kafka API key issued to Ali"
  sensitive   = true
}

variable "omar_ali_kafka_api_secret" {
  type        = string
  description = "Kafka API secret issued to Ali"
  sensitive   = true
}

# ---- Topic (hyphens only, and the app- prefix Ali's access is scoped to) ----

variable "events_topic_name" {
  type        = string
  description = "Topic Ali's microservice produces application events to"
  default     = "app-events"

  validation {
    condition     = startswith(var.events_topic_name, "app-") && !strcontains(var.events_topic_name, ".")
    error_message = "Topic names must start with 'app-' and must not contain dots."
  }
}
