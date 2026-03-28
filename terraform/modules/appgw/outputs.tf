output "appgw_id" {
  description = "Application Gateway resource ID — passed to AKS AGIC add-on"
  value       = azurerm_application_gateway.main.id
}

output "appgw_name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.main.name
}

output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway frontend"
  value       = azurerm_public_ip.appgw.ip_address
}

output "appgw_subnet_id" {
  description = "App Gateway subnet ID — passed to AKS module for AGIC role assignment"
  value       = var.appgw_subnet_id
}
