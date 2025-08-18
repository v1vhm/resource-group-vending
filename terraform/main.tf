terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    port = {
      source  = "port-labs/port-labs"
      version = ">= 2.0.0"
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

  location           = local.environment.location
  environment        = local.environment.environment
  product_name       = local.product_name
  product_identifier = local.product_identifier
  services           = local.services
}

resource "port_entity" "resource_group" {
  blueprint  = "azure_resource_group"
  identifier = module.environment.resource_group_id
  title      = module.environment.resource_group_name

  properties = {
    id       = module.environment.resource_group_id
    name     = module.environment.resource_group_name
    location = module.environment.resource_group_location
    tags     = module.environment.resource_group_tags
  }

  relations = {
    subscription = lower(data.azurerm_subscription.current.id)
  }

  run_id = var.port_run_id
}

resource "port_entity" "storage_account" {
  blueprint  = "azure_storage_account"
  identifier = module.environment.storage_account_id
  title      = module.environment.storage_account_name

  properties = {
    id                       = module.environment.storage_account_id
    name                     = module.environment.storage_account_name
    location                 = module.environment.storage_account_location
    is_hns_enabled           = module.environment.storage_account_is_hns_enabled
    primary_location         = module.environment.storage_account_primary_location
    secondary_location       = module.environment.storage_account_secondary_location
    allow_blob_public_access = module.environment.storage_account_allow_blob_public_access
    tags                     = module.environment.storage_account_tags
  }

  relations = {
    resource_group = module.environment.resource_group_id
  }

  run_id = var.port_run_id
}

resource "port_entity" "state_container" {
  blueprint  = "azure_storage_container"
  identifier = module.environment.state_file_container
  title      = module.environment.state_container_name

  properties = {
    id   = module.environment.state_file_container
    name = module.environment.state_container_name
  }

  relations = {
    storage_account = module.environment.storage_account_id
  }

  run_id = var.port_run_id
}

resource "port_entity" "user_managed_identity" {
  blueprint  = "azure_user_assigned_identity"
  identifier = module.environment.user_managed_identity_id
  title      = module.environment.user_managed_identity_name

  properties = {
    id        = module.environment.user_managed_identity_id
    name      = module.environment.user_managed_identity_name
    client_id = module.environment.user_managed_identity_client_id
    tags      = module.environment.user_managed_identity_tags
  }

  relations = {
    resource_group = module.environment.resource_group_id
  }

  run_id = var.port_run_id
}

output "deployment_environment" {
  value = port_entity.resource_group.identifier
}

output "deployment_identity" {
  value = port_entity.user_managed_identity.identifier
}

output "azure_subscription" {
  value = lower(data.azurerm_subscription.current.id)
}

output "state_file_container" {
  value = port_entity.state_container.identifier
}

output "user_managed_identity_client_id" {
  value = module.environment.user_managed_identity_client_id
}

