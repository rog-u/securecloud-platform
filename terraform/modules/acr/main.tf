# ---------------------------------------------------------------------------
# Azure Container Registry (ACR)
# Private image registry — AKS pulls images via managed identity (AcrPull role),
# so admin access is disabled. Basic SKU is sufficient for dev.
# ---------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                = replace("${var.project}${var.environment}acr", "-", "")
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}
