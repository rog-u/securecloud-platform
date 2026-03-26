#!/bin/bash
set -e

echo "🚀 Deploying PostgreSQL with ACR and Managed Identity"
echo "=================================================="

# Get ACR name from Terraform output or use default
ACR_NAME=$(terraform output -raw acr_name 2>/dev/null || echo "secureclouddevacr")

echo ""
echo "📦 Step 1: Import PostgreSQL image to ACR"
echo "ACR Name: $ACR_NAME"

# Check if image already exists
if az acr repository show --name "$ACR_NAME" --repository postgres &>/dev/null; then
    echo "✅ postgres:16-alpine already exists in ACR"
else
    echo "⬇️  Importing postgres:16-alpine from Docker Hub..."
    az acr import \
        --name "$ACR_NAME" \
        --source docker.io/library/postgres:16-alpine \
        --image postgres:16-alpine
    echo "✅ Image imported successfully"
fi

echo ""
echo "🏗️  Step 2: Apply Terraform configuration"
echo "This will:"
echo "  - Create a user-assigned managed identity"
echo "  - Grant AcrPull role to the identity"
echo "  - Deploy PostgreSQL container with the identity"
echo ""

terraform apply

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 What was created:"
echo "  1. Managed Identity: securecloud-dev-aci-identity"
echo "  2. Role Assignment: AcrPull on ACR"
echo "  3. Container Group: securecloud-dev-postgres"
echo ""
echo "🔐 Security features:"
echo "  ✓ No credentials stored in Terraform"
echo "  ✓ Automatic token rotation by Azure"
echo "  ✓ Least privilege access (AcrPull only)"
echo "  ✓ Full audit trail in Azure AD"
echo ""
echo "📖 For more details, see: docs/MANAGED_IDENTITY_SETUP.md"
