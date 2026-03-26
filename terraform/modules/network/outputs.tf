output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_location" {
  value = azurerm_resource_group.main.location
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "public_subnet_ids" {
  value = [for s in azurerm_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in azurerm_subnet.private : s.id]
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "postgres_subnet_id" {
  value = azurerm_subnet.postgres.id
}

output "postgres_subnet_delegation_ready" {
  description = "Dependency marker - ensures subnet delegation and NSG are ready"
  value       = azurerm_subnet_network_security_group_association.db.id
}

output "nsg_app_id" {
  value = azurerm_network_security_group.app.id
}

output "nsg_db_id" {
  value = azurerm_network_security_group.db.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}
