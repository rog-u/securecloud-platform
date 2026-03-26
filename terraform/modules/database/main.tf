locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# User-Assigned Managed Identity for Container Group
# This identity will be used to authenticate to ACR without credentials
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "aci" {
  name                = "${local.name_prefix}-aci-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

# Grant the managed identity permission to pull images from ACR
resource "azurerm_role_assignment" "acr_pull" {
  count                = var.acr_id != null ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aci.principal_id
}

# ---------------------------------------------------------------------------
# Storage Account for PostgreSQL Data Persistence
# Azure Files share mounted to the container for persistent database storage
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "postgres" {
  name                     = "${replace(var.project, "-", "")}${var.environment}pgdata"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

resource "azurerm_storage_share" "postgres" {
  name                 = "postgres-data"
  storage_account_name = azurerm_storage_account.postgres.name
  quota                = 10 # GB
}

# ---------------------------------------------------------------------------
# Azure Container Instance - PostgreSQL
# Runs PostgreSQL 16 in a container with persistent storage
# Deployed in the private subnet with no public IP
# Uses managed identity for secure ACR authentication
# ---------------------------------------------------------------------------

resource "azurerm_container_group" "postgres" {
  name                = "${local.name_prefix}-postgres"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  ip_address_type     = "Private"
  subnet_ids          = [var.postgres_subnet_id]

  # Assign the managed identity to this container group
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aci.id]
  }

  # Configure ACR authentication using the managed identity
  dynamic "image_registry_credential" {
    for_each = var.acr_login_server != null ? [1] : []
    content {
      server   = var.acr_login_server
      user_assigned_identity_id = azurerm_user_assigned_identity.aci.id
    }
  }

  # Wait for subnet delegation and ACR role assignment to be ready
  depends_on = [
    var.postgres_subnet_delegation_ready,
    azurerm_role_assignment.acr_pull
  ]

  container {
    name   = "postgres"
    # Use ACR image if provided, otherwise Docker Hub (may hit rate limits)
    image  = var.acr_login_server != null ? "${var.acr_login_server}/postgres:16-alpine" : "postgres:16-alpine"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 5432
      protocol = "TCP"
    }

    environment_variables = {
      POSTGRES_USER     = var.db_admin_username
      POSTGRES_DB       = "telemetry"
    }

    secure_environment_variables = {
      POSTGRES_PASSWORD = var.db_admin_password
    }

    volume {
      name                 = "postgres-data"
      mount_path           = "/var/lib/postgresql/data"
      storage_account_name = azurerm_storage_account.postgres.name
      storage_account_key  = azurerm_storage_account.postgres.primary_access_key
      share_name           = azurerm_storage_share.postgres.name
    }
  }

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}
