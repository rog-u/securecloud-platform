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
  description = "Resource group to deploy AKS into"
  type        = string
}

variable "aks_subnet_id" {
  description = "Subnet ID for AKS nodes and pods (Azure CNI — pods get VNet IPs)"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for container insights"
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID — grants the cluster AcrPull via managed identity"
  type        = string
}

variable "appgw_id" {
  description = "Application Gateway resource ID — enables AGIC as an AKS managed add-on"
  type        = string
}

variable "appgw_subnet_id" {
  description = "App Gateway subnet ID — AGIC needs Network Contributor to join it"
  type        = string
}
