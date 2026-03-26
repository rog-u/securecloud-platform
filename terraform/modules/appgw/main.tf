locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Public IP for the Application Gateway frontend
# Standard SKU is required for Application Gateway v2.
# Static allocation is required for Application Gateway (cannot use Dynamic).
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "appgw" {
  name                = "${local.name_prefix}-appgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

# ---------------------------------------------------------------------------
# Application Gateway v2
#
# Key decisions:
#   Standard_v2 SKU  — provides L7 load balancing, path-based routing, and
#     TLS termination. WAF_v2 would add OWASP ruleset protection; upgrade path
#     is in-place (SKU change only). Using Standard_v2 here to keep dev costs
#     low — the architecture supports a WAF_v2 upgrade without infra changes.
#
#   autoscale min_capacity = 0  — scales to zero when idle, avoiding the
#     ~$0.25/hr minimum charge when nothing is routing. Azure bills only for
#     data processed. Required for a dev environment without burning money.
#
#   lifecycle ignore_changes  — AGIC (the Kubernetes controller running inside
#     AKS) manages the App Gateway configuration directly: it reads Ingress
#     objects from Kubernetes and rewrites backend_address_pool, http_listener,
#     request_routing_rule, and probe on every reconcile loop. Without this
#     block, `terraform plan` would show constant drift and fight with AGIC.
#     We let AGIC own those resources; Terraform owns everything else.
# ---------------------------------------------------------------------------

resource "azurerm_application_gateway" "main" {
  name                = "${local.name_prefix}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  # Scale to zero when idle — only pay for data processed in dev
  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
  }

  # Attach to the dedicated AppGw subnet (must be /24 or larger, no other resources)
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # ---------------------------------------------------------------------------
  # The following backend/listener/routing resources are placeholder skeletons.
  # Terraform requires at least one of each to create the resource, but AGIC
  # will overwrite all of these once the AKS add-on is enabled and the first
  # Kubernetes Ingress object is deployed.
  # ---------------------------------------------------------------------------

  backend_address_pool {
    name = "default-backend-pool"
  }

  backend_http_settings {
    name                  = "default-backend-settings"
    cookie_based_affinity = "Disabled"
    port                  = 8000
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "default-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "default-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "default-listener"
    backend_address_pool_name  = "default-backend-pool"
    backend_http_settings_name = "default-backend-settings"
    priority                   = 100
  }

  lifecycle {
    # AGIC continuously rewrites these — do not let Terraform drift-correct them
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      redirect_configuration,
      url_path_map,
      tags["managed-by-k8s-ingress"],
    ]
  }

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}
