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
  }
}

provider "confluent" {
  
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
