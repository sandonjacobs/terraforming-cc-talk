variable "cloud_provider" {
  type = string
  description = "cloud provider for Confluent Cloud"
  default = "AWS"
}

variable "cloud_region" {
  type = string
  description = "cloud provider region"
  default = "us-east-2"
}

variable "org_id" {
  type = string
}

variable "cc_env_display_name" {
  type = string
  description = "Name of Confluent Cloud Environment to Manage"
  default = "current-london-2025"
}

variable "vault_addr" {
  type = string
  description = "Vault address"
  default = "https://vault.currentlondon.com"
}

variable "vault_user" {
  type = string
  description = "Vault user"
  default = "terraforming"
}

variable "vault_password" {
  type = string
  description = "Vault password"
  default = "terraforming"
}

