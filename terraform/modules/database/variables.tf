variable "project" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "vnet_id" { type = string }
variable "postgres_subnet_id" { type = string }

variable "postgres_subnet_delegation_ready" {
  description = "Dependency marker to ensure subnet delegation is ready before creating container group"
  type        = any
  default     = null
}

variable "acr_id" {
  description = "Azure Container Registry ID for granting AcrPull role"
  type        = string
  default     = null
}

variable "acr_login_server" {
  description = "ACR login server URL (e.g., myregistry.azurecr.io)"
  type        = string
  default     = null
}

variable "db_admin_username" {
  description = "PostgreSQL administrator login name"
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password — set via terraform.tfvars"
  type        = string
  sensitive   = true
}
