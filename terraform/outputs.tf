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
