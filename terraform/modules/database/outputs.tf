output "server_fqdn" {
  description = "Private IP address of the PostgreSQL container"
  value       = azurerm_container_group.postgres.ip_address
}

output "database_name" {
  description = "Name of the telemetry database"
  value       = "telemetry"
}

output "server_id" {
  description = "Container group resource ID"
  value       = azurerm_container_group.postgres.id
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${var.db_admin_username}@${azurerm_container_group.postgres.ip_address}:5432/telemetry"
  sensitive   = true
}

output "managed_identity_id" {
  description = "User-assigned managed identity ID for the container group"
  value       = azurerm_user_assigned_identity.aci.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the managed identity (for role assignments)"
  value       = azurerm_user_assigned_identity.aci.principal_id
}
