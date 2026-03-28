module "network" {
  source = "./modules/network"

  project                 = var.project
  environment             = var.environment
  location                = var.location
  vnet_address_space      = var.vnet_address_space
  public_subnet_prefixes  = var.public_subnet_prefixes
  private_subnet_prefixes = var.private_subnet_prefixes
  aks_subnet_prefix       = var.aks_subnet_prefix
  appgw_subnet_prefix     = var.appgw_subnet_prefix
  postgres_subnet_prefix  = var.postgres_subnet_prefix
}

module "appgw" {
  source = "./modules/appgw"

  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = module.network.resource_group_name
  appgw_subnet_id     = module.network.appgw_subnet_id
}

module "aks" {
  source = "./modules/aks"

  project                    = var.project
  environment                = var.environment
  location                   = var.location
  resource_group_name        = module.network.resource_group_name
  aks_subnet_id              = module.network.aks_subnet_id
  log_analytics_workspace_id = module.network.log_analytics_workspace_id
  acr_id                     = module.acr.acr_id
  appgw_id                   = module.appgw.appgw_id
  appgw_subnet_id            = module.appgw.appgw_subnet_id

  depends_on = [module.acr, module.appgw]
}

module "acr" {
  source = "./modules/acr"

  project             = var.project
  environment         = var.environment
  location            = var.location
  resource_group_name = module.network.resource_group_name
}

