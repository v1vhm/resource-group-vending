terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
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

resource "azurerm_storage_container" "tfstate" {
  name                 = "tfstate"
  storage_account_name = azurerm_storage_account.sa.name
}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-${var.product_identifier}-${var.environment}-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

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

output "resource_group_id" {
  value = lower(azurerm_resource_group.rg.id)
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "user_managed_identity_id" {
  value = lower(azurerm_user_assigned_identity.uai.id)
}

output "state_file_container" {
  value = lower("${azurerm_storage_account.sa.name}-tfstate")
}

output "user_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.uai.client_id
}
