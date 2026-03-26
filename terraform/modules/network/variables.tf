variable "project" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "vnet_address_space" { type = string }
variable "public_subnet_prefixes" { type = list(string) }
variable "private_subnet_prefixes" { type = list(string) }
