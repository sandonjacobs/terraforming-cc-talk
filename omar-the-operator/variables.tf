variable "organization_id" {
  type        = string
  description = "Confluent Cloud organization ID (a UUID). Required: set TF_VAR_organization_id in your shell. Omar publishes it as OMAR_ORGANIZATION_ID for the other personas."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.organization_id))
    error_message = "organization_id must be an organization UUID, for example 1b2c3d4e-0000-1111-2222-333344445555."
  }
}

variable "cloud_provider" {
  type        = string
  description = "Cloud provider for the Kafka cluster and Flink compute pool"
  default     = "AWS"
}

variable "cloud_region" {
  type        = string
  description = "Cloud region for the Kafka cluster and Flink compute pool"
  default     = "us-east-2"
}

variable "cc_env_display_name" {
  type        = string
  description = "Display name of the Confluent Cloud environment"
  default     = "talmbout-tf-cc"
}

variable "cc_kafka_cluster_name" {
  type        = string
  description = "Display name of the Standard Kafka cluster"
  default     = "tf-cc-demo"
}

variable "flink_max_cfu" {
  type        = number
  description = "Maximum CFUs for the Flink compute pool (kept small for a demo)"
  default     = 5
}
