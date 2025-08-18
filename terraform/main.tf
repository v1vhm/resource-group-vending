terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}

locals {
  environment        = yamldecode(file(var.environment_file))
  product_name       = local.environment.product_name
  product_identifier = local.environment.product_identifier
  services           = try(local.environment.services, [])
}

module "environment" {
  source = "./modules/resource_group"

  location           = local.environment.location
  environment        = local.environment.environment
  product_name       = local.product_name
  product_identifier = local.product_identifier
  services           = local.services
}

output "deployment_environment" {
  value = module.environment.resource_group_id
}

output "deployment_identity" {
  value = module.environment.user_managed_identity_id
}

output "azure_subscription" {
  value = lower(data.azurerm_subscription.current.id)
}

output "state_file_container" {
  value = module.environment.state_file_container
}

output "user_managed_identity_client_id" {
  value = module.environment.user_managed_identity_client_id
}

