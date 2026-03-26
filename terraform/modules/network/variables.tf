variable "project" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "vnet_address_space" { type = string }
variable "public_subnet_prefixes" { type = list(string) }
variable "private_subnet_prefixes" { type = list(string) }

# Phase 2a subnets
variable "aks_subnet_prefix" {
  description = "CIDR for the AKS node/pod subnet (Azure CNI needs lots of IPs)"
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
