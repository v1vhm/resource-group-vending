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
  environment_files = fileset("${path.module}/../environments", "*.yaml")
  environments = {
    for file in local.environment_files :
    trimsuffix(basename(file), ".yaml") => yamldecode(file("${path.module}/../environments/${file}"))
  }
}

module "environments" {
  source   = "./modules/resource_group"
  for_each = local.environments

  environment_name       = each.value.environment_name
  environment_short_name = each.value.environment_short_name
  location               = each.value.location
  environment            = each.value.environment
  service_identifier     = each.value.service_identifier
  github_org             = each.value.github.org
  github_repo            = each.value.github.repo
  github_entity          = each.value.github.entity
  github_entity_name     = each.value.github.entity_name
  port_run_id            = var.port_run_id
}

resource "port_entity" "environment" {
  for_each = local.environments

  blueprint  = "environment"
  identifier = "${each.value.service_identifier}_${each.value.environment}"
  title      = "${each.value.service_identifier}-${each.value.environment}"

  properties = {
    environment_type = "Azure Resource Group"
  }

  relations = {
    single_relations = {
      deployment_environment = module.environments[each.key].resource_group_name
      deployment_identity    = module.environments[each.key].user_managed_identity_id
      azure_subscription     = data.azurerm_subscription.current.id
    }
  }

  run_id = var.port_run_id
}

output "resource_group_ids" {
  value = { for k, m in module.environments : k => m.resource_group_id }
}
