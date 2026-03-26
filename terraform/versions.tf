terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    resource_group {
      # Allow destroying RGs that contain auto-provisioned resources
      # (e.g. Traffic Analytics creates dataCollectionEndpoints/Rules)
      prevent_deletion_if_contains_resources = false
    }
  }
}
