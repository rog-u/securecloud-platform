variable "project" {
  description = "Project name — used in resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy the Application Gateway into"
  type        = string
}

variable "appgw_subnet_id" {
  description = "Dedicated subnet ID for the Application Gateway (must not contain other resources)"
  type        = string
}
