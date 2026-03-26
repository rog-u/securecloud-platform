output "resource_group_name" {
  description = "Name of the resource group containing all network resources"
  value       = module.network.resource_group_name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.network.vnet_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}

output "nsg_app_id" {
  description = "NSG ID for the application tier"
  value       = module.network.nsg_app_id
}

output "nsg_db_id" {
  description = "NSG ID for the database tier"
  value       = module.network.nsg_db_id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "Private API server FQDN (reachable from within VNet only)"
  value       = module.aks.cluster_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity (Phase 2b)"
  value       = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  description = "ACR login server for image pushes"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "ACR name for az acr commands"
  value       = module.acr.acr_name
}

output "appgw_public_ip" {
  description = "Public IP of the Application Gateway — hit this to reach the telemetry API"
  value       = module.appgw.appgw_public_ip
}

output "appgw_name" {
  description = "Application Gateway name"
  value       = module.appgw.appgw_name
}
