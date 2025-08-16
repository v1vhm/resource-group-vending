terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    port = {
      source  = "port-labs/port-labs"
      version = "~> 2"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "port" {}

data "azurerm_subscription" "current" {}

locals {
  environment        = yamldecode(file(var.environment_file))
  product_name       = local.environment.product_name
  product_identifier = local.environment.product_identifier
  services           = try(local.environment.services, [])
}

module "environment" {
  source = "./modules/resource_group"

  environment_name       = local.environment.environment_name
  environment_short_name = local.environment.environment_short_name
  location               = local.environment.location
  environment            = local.environment.environment
  product_name           = local.product_name
  product_identifier     = local.product_identifier
  services               = local.services
  port_run_id            = var.port_run_id
}

resource "port_entity" "environment" {
  blueprint  = "environment"
  identifier = "${local.product_identifier}_${local.environment.environment}_${local.environment.location}"
  title      = "${local.product_identifier}-${local.environment.environment}-${local.environment.location}"

  properties = {
    environment_type = "Azure Resource Group"
  }

  relations = {
    single_relations = {
      deployment_environment = module.environment.resource_group_id
      deployment_identity    = module.environment.user_managed_identity_id
      azure_subscription     = lower(data.azurerm_subscription.current.id)
      product                = local.product_identifier
    }
    many_relations = length(local.services) > 0 ? {
      deployed_service = [for s in local.services : s.service_identifier]
    } : null
  }

  run_id = var.port_run_id
}

output "resource_group_id" {
  value = module.environment.resource_group_id
}
