locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Resource Group
# Azure requires every resource to live in a Resource Group — a logical
# container for billing, access control, and lifecycle management.
# Deleting the resource group deletes everything inside it.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

# ---------------------------------------------------------------------------
# Virtual Network (VNet)
# Azure equivalent of AWS VPC — your isolated private network.
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]

  tags = { Name = "${local.name_prefix}-vnet" }
}

# ---------------------------------------------------------------------------
# Subnets
# Unlike AWS, Azure subnets are regional — they span all zones in a region.
# You control which Availability Zone a VM/pod lands in at the resource level.
# ---------------------------------------------------------------------------

resource "azurerm_subnet" "public" {
  count = length(var.public_subnet_prefixes)

  name                 = "${local.name_prefix}-public-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_prefixes[count.index]]
}

resource "azurerm_subnet" "private" {
  count = length(var.private_subnet_prefixes)

  name                 = "${local.name_prefix}-private-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_prefixes[count.index]]
}

# ---------------------------------------------------------------------------
# Phase 2a Subnets
# ---------------------------------------------------------------------------

# AKS subnet — Azure CNI assigns a VNet IP to every pod, so this needs to be
# large (/18 = 16K IPs). No user-managed NSG — AKS creates its own on the
# node NICs and needs to add rules dynamically for load balancers and probes.
resource "azurerm_subnet" "aks" {
  name                 = "${local.name_prefix}-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# Application Gateway subnet — must be dedicated (no other resources).
# No user-managed NSG — App Gateway v2 requires GatewayManager access
# and manages its own required rules.
resource "azurerm_subnet" "appgw" {
  name                 = "${local.name_prefix}-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_prefix]
}

# PostgreSQL subnet — delegated to Azure Container Instances
# for running containerized PostgreSQL with VNet integration
resource "azurerm_subnet" "postgres" {
  name                 = "${local.name_prefix}-postgres"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.postgres_subnet_prefix]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# ---------------------------------------------------------------------------
# NAT Gateway
# Gives private subnet resources outbound internet access (for pulling images,
# calling APIs) without exposing them inbound.
# Unlike AWS, Azure NAT Gateway is zone-redundant by default when no zone is set.
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "nat" {
  name                = "${local.name_prefix}-nat-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = { Name = "${local.name_prefix}-nat-pip" }
}

resource "azurerm_nat_gateway" "main" {
  name                = "${local.name_prefix}-nat"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"

  tags = { Name = "${local.name_prefix}-nat" }
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Associate the NAT Gateway with each private subnet
resource "azurerm_subnet_nat_gateway_association" "private" {
  count = length(var.private_subnet_prefixes)

  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# AKS nodes need outbound internet for image pulls, DNS, Azure API calls
resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# PostgreSQL Flexible Server needs outbound for Azure management traffic
resource "azurerm_subnet_nat_gateway_association" "postgres" {
  subnet_id      = azurerm_subnet.postgres.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ---------------------------------------------------------------------------
# Network Security Groups (NSGs)
# In Azure, NSGs serve the role of BOTH AWS Security Groups (stateful, per-resource)
# AND NACLs (subnet-level). One tool instead of two.
#
# Rules: lower priority number = evaluated first.
# Default built-in rules at priority 65000-65500 deny all inbound not matched above.
# ---------------------------------------------------------------------------

# Public tier NSG: allow HTTPS from the internet (for App Gateway in Phase 2)
resource "azurerm_network_security_group" "public" {
  name                = "${local.name_prefix}-nsg-public"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = { Name = "${local.name_prefix}-nsg-public" }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  count = length(var.public_subnet_prefixes)

  subnet_id                 = azurerm_subnet.public[count.index].id
  network_security_group_id = azurerm_network_security_group.public.id
}

# App tier NSG: only allow port 8000 from the public subnets (where App Gateway lives)
resource "azurerm_network_security_group" "app" {
  name                = "${local.name_prefix}-nsg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow inbound API traffic from the public subnet range only
  security_rule {
    name                       = "Allow-API-From-Public"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefixes    = var.public_subnet_prefixes
    destination_address_prefix = "*"
  }

  # Explicitly deny all other inbound traffic (belt-and-suspenders — default rules do this too)
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = { Name = "${local.name_prefix}-nsg-app" }
}

# DB tier NSG: only allow PostgreSQL from the private app subnets
resource "azurerm_network_security_group" "db" {
  name                = "${local.name_prefix}-nsg-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-Postgres-From-App"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefixes    = concat(var.private_subnet_prefixes, [var.aks_subnet_prefix])
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = { Name = "${local.name_prefix}-nsg-db" }
}

# Associate the app NSG with each private subnet
resource "azurerm_subnet_network_security_group_association" "app" {
  count = length(var.private_subnet_prefixes)

  subnet_id                 = azurerm_subnet.private[count.index].id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Associate the DB NSG with the postgres subnet
resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.postgres.id
  network_security_group_id = azurerm_network_security_group.db.id
}

# ---------------------------------------------------------------------------
# Network Watcher Flow Logs
# Azure equivalent of AWS VPC Flow Logs — captures every accepted/rejected
# packet for security analysis and incident investigation.
# ---------------------------------------------------------------------------

# Azure auto-creates exactly one Network Watcher per region per subscription
# in a resource group called "NetworkWatcherRG". We read it with a data source
# rather than creating a new one (Azure only allows 1 per region).
data "azurerm_network_watcher" "main" {
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"
}

# Storage account to hold the raw flow log files
resource "azurerm_storage_account" "flow_logs" {
  name                     = replace("${var.project}${var.environment}flowlogs", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  tags = { Name = "${local.name_prefix}-flow-logs-sa" }
}

# Log Analytics Workspace — central log store, feeds into Defender for Cloud
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = { Name = "${local.name_prefix}-law" }
}

resource "azurerm_network_watcher_flow_log" "app" {
  network_watcher_name = data.azurerm_network_watcher.main.name
  resource_group_name  = data.azurerm_network_watcher.main.resource_group_name
  name                 = "${local.name_prefix}-flow-log"
  # VNet flow logs replace deprecated NSG flow logs (NSG flow log creation
  # blocked by Azure as of June 30, 2025; retired September 30, 2027).
  target_resource_id = azurerm_virtual_network.main.id
  storage_account_id = azurerm_storage_account.flow_logs.id
  enabled            = true

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main.workspace_id
    workspace_region      = azurerm_resource_group.main.location
    workspace_resource_id = azurerm_log_analytics_workspace.main.id
    interval_in_minutes   = 10
  }
}
