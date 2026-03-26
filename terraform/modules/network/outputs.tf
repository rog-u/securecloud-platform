output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "public_subnet_ids" {
  value = [for s in azurerm_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in azurerm_subnet.private : s.id]
}

output "nsg_app_id" {
  value = azurerm_network_security_group.app.id
}

output "nsg_db_id" {
  value = azurerm_network_security_group.db.id
}
