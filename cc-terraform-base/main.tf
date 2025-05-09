# Configure the Confluent Provider
terraform {
  backend "local" {
    workspace_dir = "~/.terraform-state/terraforming-talk/cc-terraform-base/.tfstate/terraform.state"
  }

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.25.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "4.5.0"
    }
  }
}

provider "confluent" {
}

resource "confluent_environment" "cc_env" {
  display_name = var.cc_env_display_name

  stream_governance {
    package = "ADVANCED"
  }

  lifecycle {
    prevent_destroy = false
  }
}

provider "vault" {
  auth_login {
    path = "auth/userpass/login/${var.vault_user}"
    parameters = {
      password = var.vault_password
    }
  }
  address = var.vault_addr
#   token = "root"
}


data "confluent_organization" "cc_org" {

}