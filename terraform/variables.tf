variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "7608358f-1d57-4d87-ad7b-0eabc551e9aa"
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
  default     = "eastus2"
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
