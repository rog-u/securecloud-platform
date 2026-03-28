# Managed Identity Setup — SecureCloud Platform

No passwords, service principal secrets, or ACR admin credentials are stored anywhere in this project.
All Azure API calls use token exchange via Azure AD managed identities.

---

## Identities in Use

### 1. AKS Control Plane Identity (User-Assigned)

**Resource:** `azurerm_user_assigned_identity.aks` in `modules/aks/`
**Purpose:** AKS uses this to manage its own Azure resources — node NICs, load balancer rules, public IPs for Services.

Why user-assigned (not system-assigned): The identity must exist *before* the cluster so we can pre-grant Network Contributor on the subnet. System-assigned identities don't exist until the cluster is created — circular dependency.

---

### 2. Kubelet Identity (Auto-Created by AKS)

**Purpose:** AKS nodes use this to pull container images from ACR. No passwords on the nodes.

The `AcrPull` role assignment is in Terraform:
```hcl
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
```

---

### 3. AGIC Identity (Auto-Created by AKS Add-On)

**Purpose:** AGIC reads Kubernetes Ingress objects and rewrites App Gateway routing rules. Needs Azure RBAC to call the Azure API.

Three role assignments are required (all managed in Terraform):

| Role | Scope | Why |
|------|-------|-----|
| Reader | Resource group | Discover and read the App Gateway |
| Contributor | App Gateway resource | Rewrite backend pools, routing rules, health probes |
| Network Contributor | App Gateway subnet | Required by Azure when updating App Gateway config |

Without all three, AGIC crashes with 403 errors and the App Gateway backend pool stays empty (clients get 502).

```hcl
locals {
  agic_principal_id = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

resource "azurerm_role_assignment" "agic_rg_reader" {
  scope                = "/subscriptions/.../resourceGroups/securecloud-dev-rg"
  role_definition_name = "Reader"
  principal_id         = local.agic_principal_id
}

resource "azurerm_role_assignment" "agic_appgw_contributor" {
  scope                = var.appgw_id
  role_definition_name = "Contributor"
  principal_id         = local.agic_principal_id
}

resource "azurerm_role_assignment" "agic_subnet_network_contributor" {
  scope                = var.appgw_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = local.agic_principal_id
}
```

---

## What Was Removed

The project originally used an Azure Container Instance (ACI) with a User-Assigned Managed Identity for PostgreSQL. This was removed because:

1. **Azure Files (SMB) incompatible with PostgreSQL**: ACI only supports Azure Files for persistent volumes. SMB does not support POSIX `chown`. PostgreSQL requires its data directory be owned by the `postgres` user — it crashes with `wrong ownership` on an SMB mount.
2. **Replaced with StatefulSet + Azure Disk**: PostgreSQL now runs as a Kubernetes StatefulSet with a PVC backed by `managed-csi` (Azure Disk). Azure Disk is a block device (ext4) with full POSIX permission support.
3. **Simpler architecture**: Everything runs in AKS. No separate ACI networking, no separate managed identity, no cross-subnet routing required.

---

## Phase 2b Upgrade Path

Pod-level credentials will be replaced with **Workload Identity**:

```
Pod (K8s service account) → OIDC token → Azure AD federation → access token → Key Vault secret
```

This eliminates Kubernetes Secrets from etcd entirely. `oidc_issuer_enabled = true` is already set in the AKS Terraform config in preparation.
