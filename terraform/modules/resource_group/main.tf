terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    port = {
      source = "port-labs/port-labs"
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.product_identifier}-${var.environment}-${var.location}"
  location = var.location
  tags = {
    environment        = var.environment
    product_identifier = var.product_identifier
    product_name       = var.product_name
  }
}

resource "azurerm_storage_account" "sa" {
  name                     = "st${lower(var.product_identifier)}${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = azurerm_resource_group.rg.tags
}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-${var.product_identifier}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "owner" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}

resource "azurerm_federated_identity_credential" "github" {
  for_each            = { for s in var.services : s.service_identifier => s }
  name                = "fic-${var.product_identifier}-${var.environment}-${each.key}"
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.uai.id
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${each.value.github.org}/${each.value.github.repo}:${each.value.github.entity}:${each.value.github.entity_name}"
  audience            = ["api://AzureADTokenExchange"]
}

resource "port_entity" "resource_group" {
  blueprint  = "azureResourceGroup"
  identifier = lower(azurerm_resource_group.rg.id)
  title      = azurerm_resource_group.rg.name

  properties = {
    location = azurerm_resource_group.rg.location
    tags     = azurerm_resource_group.rg.tags
  }

  relations = {
    single_relations = {
      subscription = lower(data.azurerm_subscription.current.id)
    }
  }

  run_id = var.port_run_id
}

resource "port_entity" "storage_account" {
  blueprint  = "azureStorageAccount"
  identifier = lower(azurerm_storage_account.sa.id)
  title      = azurerm_storage_account.sa.name

  properties = {
    location              = azurerm_storage_account.sa.location
    isHnsEnabled          = azurerm_storage_account.sa.is_hns_enabled
    primaryLocation       = azurerm_storage_account.sa.primary_location
    secondaryLocation     = azurerm_storage_account.sa.secondary_location
    allowBlobPublicAccess = azurerm_storage_account.sa.allow_nested_items_to_be_public
    tags                  = azurerm_storage_account.sa.tags
  }

  relations = {
    single_relations = {
      resourceGroup = lower(port_entity.resource_group.identifier)
    }
  }

  run_id = var.port_run_id
}

resource "port_entity" "user_managed_identity" {
  blueprint  = "azureUserManagedIdentity"
  identifier = lower(azurerm_user_assigned_identity.uai.id)
  title      = azurerm_user_assigned_identity.uai.name

  properties = {
    clientId = azurerm_user_assigned_identity.uai.client_id
    tags     = azurerm_user_assigned_identity.uai.tags
  }

  relations = {
    single_relations = {
      resource_group = lower(port_entity.resource_group.identifier)
    }
  }

  run_id = var.port_run_id
}

output "resource_group_id" {
  value = lower(azurerm_resource_group.rg.id)
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "user_managed_identity_id" {
  value = lower(azurerm_user_assigned_identity.uai.id)
}
