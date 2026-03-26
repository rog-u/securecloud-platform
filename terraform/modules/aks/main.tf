locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# User-Assigned Managed Identity for the AKS cluster control plane
#
# We use UserAssigned (not SystemAssigned) to break the circular dependency:
#   SystemAssigned: identity doesn't exist until cluster is created, so you
#   can't pre-grant Network Contributor on the subnet before apply.
#   UserAssigned: create identity → grant permissions → create cluster.
#
# AKS uses this identity to manage its own Azure resources (node NICs,
# load balancers, public IPs for Services). The kubelet identity is separate
# and is auto-created by AKS for node → ACR authentication.
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${local.name_prefix}-aks-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

# AKS needs Network Contributor on the subnet to attach node NICs and manage
# networking resources. Required when outbound_type = "userAssignedNATGateway".
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# ---------------------------------------------------------------------------
# AKS Cluster
#
# Key security decisions:
#   private_cluster_enabled = true  — API server endpoint is private (no public
#     internet exposure). kubectl commands must originate from within the VNet
#     or via VPN/bastion. Equivalent to EKS with private endpoint only.
#
#   network_plugin = "azure" (Azure CNI)  — every pod gets a real VNet IP from
#     the AKS subnet. This enables Network Policies and avoids the NAT that
#     kubenet uses. Required for AGIC to route directly to pod IPs.
#
#   network_policy = "azure"  — enables Kubernetes Network Policy enforcement.
#     Without this, NetworkPolicy objects are accepted but not enforced.
#     Phase 2b will add default-deny + explicit-allow policies.
#
#   outbound_type = "userAssignedNATGateway"  — use the NAT Gateway deployed
#     in Phase 1 for node outbound traffic (image pulls, DNS, Azure APIs).
#     Prevents AKS from creating its own outbound load balancer rules.
#
#   oidc_issuer_enabled = true  — exposes the cluster's OIDC endpoint, which
#     is required for Workload Identity federation in Phase 2b. Pods can then
#     exchange a Kubernetes service account token for an Azure AD token without
#     any stored credentials.
#
#   oms_agent (Container Insights)  — sends pod/node metrics and stdout/stderr
#     logs to the Log Analytics Workspace created in Phase 1. Required for
#     Defender for Containers in Phase 3.
# ---------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "main" {
  name                    = "${local.name_prefix}-aks"
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = "${local.name_prefix}-aks"
  kubernetes_version      = "1.32"
  private_cluster_enabled = true
  oidc_issuer_enabled     = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  default_node_pool {
    name                         = "system"
    node_count                   = 1
    vm_size                      = "Standard_D2s_v3"
    vnet_subnet_id               = var.aks_subnet_id
    os_disk_size_gb              = 30
    os_disk_type                 = "Managed"
    only_critical_addons_enabled = true # system pool: kube-system workloads only
  }

  network_profile {
    network_plugin    = "azure"                  # Azure CNI: pods get real VNet IPs
    network_policy    = "azure"                  # enforce NetworkPolicy objects
    load_balancer_sku = "standard"
    outbound_type     = "userAssignedNATGateway" # use the NAT GW from Phase 1
    service_cidr      = "172.16.0.0/16"          # must not overlap VNet (10.0.0.0/16)
    dns_service_ip    = "172.16.0.10"            # must be within service_cidr
  }

  # Container Insights — feeds into Log Analytics Workspace (already deployed)
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # ---------------------------------------------------------------------------
  # AGIC (Application Gateway Ingress Controller) managed add-on
  #
  # The add-on approach (vs. Helm chart) is preferred because Azure manages
  # the AGIC pod lifecycle, upgrades, and its own managed identity. AGIC reads
  # Kubernetes Ingress objects and rewrites the App Gateway config to match —
  # no manual routing rules needed after the first Ingress is deployed.
  #
  # This is an in-place update to the existing cluster. AKS does not recreate
  # nodes or drain workloads when add-ons are enabled.
  # ---------------------------------------------------------------------------
  ingress_application_gateway {
    gateway_id = var.appgw_id
  }

  depends_on = [azurerm_role_assignment.aks_network_contributor]

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

# ---------------------------------------------------------------------------
# User node pool — runs application workloads
# Separated from the system pool so kube-system components are not co-located
# with application pods. In Phase 2b, taint/toleration ensures telemetry API
# pods only land here.
# ---------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D2s_v3"
  node_count            = 1
  vnet_subnet_id        = var.aks_subnet_id
  mode                  = "User"

  tags = { Project = var.project, Environment = var.environment, ManagedBy = "terraform" }
}

# ---------------------------------------------------------------------------
# AcrPull role assignment — kubelet identity pulls images from ACR
# AKS auto-creates a kubelet managed identity for node → ACR authentication.
# No stored credentials — nodes exchange their managed identity token for an
# ACR refresh token via Azure AD.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
