variable "subscription_id" {
  description = "Azure Subscription ID — set via terraform.tfvars or TF_VAR_subscription_id"
  type        = string
}

variable "project" {
  description = "Project name — used in resource names and tags"
  type        = string
  default     = "securecloud"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

# Azure uses "location" instead of AWS "region"
variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "westus2"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

# In Azure, subnets are regional — they span all Availability Zones.
# You control which zone a VM/pod lands in at the resource level, not subnet level.
variable "public_subnet_prefixes" {
  description = "CIDR blocks for public subnets (used by load balancer / App Gateway)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_prefixes" {
  description = "CIDR blocks for private subnets (used by app pods and database)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# Phase 2a subnets
variable "aks_subnet_prefix" {
  description = "CIDR for the AKS node/pod subnet (large — Azure CNI gives every pod a VNet IP)"
  type        = string
  default     = "10.0.64.0/18"
}

variable "appgw_subnet_prefix" {
  description = "CIDR for the Application Gateway subnet (must be dedicated)"
  type        = string
  default     = "10.0.4.0/24"
}

variable "postgres_subnet_prefix" {
  description = "CIDR for the PostgreSQL Flexible Server delegated subnet"
  type        = string
  default     = "10.0.14.0/24"
}

# Database credentials
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
