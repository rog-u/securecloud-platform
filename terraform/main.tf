module "network" {
  source = "./modules/network"

  project                 = var.project
  environment             = var.environment
  location                = var.location
  vnet_address_space      = var.vnet_address_space
  public_subnet_prefixes  = var.public_subnet_prefixes
  private_subnet_prefixes = var.private_subnet_prefixes
}
