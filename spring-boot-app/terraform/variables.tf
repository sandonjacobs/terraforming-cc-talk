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


variable "vault_addr" {
  type = string
  description = "Vault address"
}

variable "vault_user" {
  type = string
  description = "Vault user"
}

variable "vault_password" {
  type = string
  description = "Vault password"
}

variable "vault_path" {
  type = string
  description = "Vault path"
  default = "secret/current-london-2025"
}
