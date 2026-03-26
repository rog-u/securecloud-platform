# Managed Identity Setup for ACI + ACR

## How It Works

This setup uses Azure Managed Identities for secure, credential-free authentication between Azure Container Instances (ACI) and Azure Container Registry (ACR).

### Architecture Flow

```
1. User-Assigned Managed Identity Created
   └─> Identity exists in Azure AD with a unique Principal ID

2. Role Assignment
   └─> Identity granted "AcrPull" role on the ACR
   └─> This permission allows pulling container images

3. Container Group Configuration
   └─> ACI assigned the managed identity
   └─> When pulling images, ACI uses Azure's internal token service
   └─> Token service validates identity and returns access token
   └─> ACR validates token and allows image pull

4. No Credentials Needed
   └─> No passwords stored in Terraform
   └─> No admin credentials enabled on ACR
   └─> Tokens automatically rotated by Azure
```

## Components

### 1. User-Assigned Managed Identity
**Resource:** `azurerm_user_assigned_identity.aci`
**Purpose:** Provides an Azure AD identity for the container group

```hcl
resource "azurerm_user_assigned_identity" "aci" {
  name                = "${local.name_prefix}-aci-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}
```

### 2. Role Assignment
**Resource:** `azurerm_role_assignment.acr_pull`
**Purpose:** Grants the identity permission to pull images from ACR

```hcl
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aci.principal_id
}
```

**AcrPull Role Permissions:**
- Read repository metadata
- Pull container images
- List repositories and tags
- Does NOT allow push or delete operations

### 3. Container Group Identity Assignment
**Resource:** `azurerm_container_group.postgres`
**Purpose:** Assigns the managed identity to the container group

```hcl
identity {
  type         = "UserAssigned"
  identity_ids = [azurerm_user_assigned_identity.aci.id]
}
```

## Security Benefits

1. **No Credential Storage**: No passwords in code, state files, or environment variables
2. **Automatic Rotation**: Azure handles token lifecycle automatically
3. **Least Privilege**: Identity only has AcrPull permission, nothing more
4. **Audit Trail**: All access logged in Azure AD and ACR activity logs
5. **No Admin Access**: ACR admin credentials remain disabled

## Deployment Steps

### Step 1: Import PostgreSQL Image to ACR
```bash
cd terraform

# Get your ACR name
ACR_NAME=$(terraform output -raw acr_name 2>/dev/null || echo "secureclouddevacr")

# Import the postgres image
az acr import \
  --name $ACR_NAME \
  --source docker.io/library/postgres:16-alpine \
  --image postgres:16-alpine
```

### Step 2: Apply Terraform
```bash
terraform apply
```

Terraform will:
1. Create the managed identity
2. Grant AcrPull role to the identity
3. Create the container group with the identity assigned
4. ACI automatically authenticates to ACR using the identity

## Troubleshooting

### Image Pull Fails
```bash
# Check if image exists in ACR
az acr repository show --name $ACR_NAME --repository postgres

# Check role assignment
az role assignment list \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME \
  --query "[?roleDefinitionName=='AcrPull']"
```

### Identity Not Working
```bash
# Verify identity exists
az identity show \
  --name securecloud-dev-aci-identity \
  --resource-group securecloud-dev-rg

# Check container group identity assignment
az container show \
  --name securecloud-dev-postgres \
  --resource-group securecloud-dev-rg \
  --query identity
```

## Comparison: Managed Identity vs Admin Credentials

| Aspect | Managed Identity | Admin Credentials |
|--------|------------------|-------------------|
| Security | ✅ No secrets | ❌ Password in state |
| Rotation | ✅ Automatic | ❌ Manual |
| Audit | ✅ Azure AD logs | ⚠️ Limited |
| Least Privilege | ✅ Role-based | ❌ Full admin |
| Complexity | ⚠️ More setup | ✅ Simple |
| Production Ready | ✅ Yes | ❌ Not recommended |

## Additional Resources

- [Azure Managed Identities Overview](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [ACI with Managed Identity](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-managed-identity)
- [ACR Authentication Options](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-authentication)
