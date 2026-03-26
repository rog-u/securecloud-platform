# Remote state: run terraform/bootstrap first to create the storage account,
# then fill in the storage_account_name below and run `terraform init`.
#
# Unlike AWS (which needs a separate DynamoDB table for locking), Azure's
# azurerm backend handles locking automatically via blob lease — no extra
# resources needed.
terraform {
  backend "azurerm" {
    resource_group_name  = "securecloud-tfstate-rg"
    storage_account_name = "sctfstate7608358f1d574d"
    container_name       = "tfstate"
    key                  = "securecloud/terraform.tfstate"
  }
}
