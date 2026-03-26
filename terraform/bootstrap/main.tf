# Bootstrap — run this ONCE before using the remote backend.
# Creates the Storage Account and container that terraform/backend.tf references.
#
# Steps:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#   Copy the storage_account_name output into ../backend.tf
#   cd .. && terraform init

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # No remote backend here — this is local state intentionally
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  # Storage account names: 3-24 chars, lowercase alphanumeric only, globally unique
  # Using the last 8 chars of the subscription ID for uniqueness
  storage_account_name = "sctfstate${substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 14)}"
}

resource "azurerm_resource_group" "tfstate" {
  name     = "securecloud-tfstate-rg"
  location = "westus2"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # State files contain sensitive infrastructure details — lock them down
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true # recover from accidental state corruption
  }

  lifecycle {
    prevent_destroy = false # never accidentally delete state storage
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

output "storage_account_name" {
  description = "Copy this into terraform/backend.tf storage_account_name"
  value       = azurerm_storage_account.tfstate.name
}
