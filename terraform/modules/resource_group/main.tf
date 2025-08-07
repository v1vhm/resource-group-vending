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
  name     = "rg-${var.environment_short_name}-${var.environment}"
  location = var.location
  tags = {
    environment_name       = var.environment_name
    environment_short_name = var.environment_short_name
    network_size           = var.network_size
    environment            = var.environment
    service_identifier     = var.service_identifier
    github_org             = var.github_org
    github_repo            = var.github_repo
  }
}

resource "azurerm_storage_account" "sa" {
  name                     = "st${lower(var.environment_short_name)}${var.environment}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = azurerm_resource_group.rg.tags
}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-${var.environment_short_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "owner" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}

resource "azurerm_federated_identity_credential" "github" {
  name                = "fic-${var.environment_short_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.uai.id
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_org}/${var.github_repo}:${var.github_entity}:${var.github_entity_name}"
  audience            = ["api://AzureADTokenExchange"]
}

resource "port_entity" "resource_group" {
  blueprint  = "azureResourceGroup"
  identifier = azurerm_resource_group.rg.name
  title      = azurerm_resource_group.rg.name

  properties = {
    location = azurerm_resource_group.rg.location
    tags     = azurerm_resource_group.rg.tags
  }

  relations = {
    single_relations = {
      environment = "${var.service_identifier}_${var.environment}"
    }
  }
}

resource "port_entity" "storage_account" {
  blueprint  = "azureStorageAccount"
  identifier = azurerm_storage_account.sa.name
  title      = azurerm_storage_account.sa.name

  properties = {
    location          = azurerm_storage_account.sa.location
    isHnsEnabled      = azurerm_storage_account.sa.is_hns_enabled
    primaryLocation   = azurerm_storage_account.sa.primary_location
    secondaryLocation = azurerm_storage_account.sa.secondary_location
    tags              = azurerm_storage_account.sa.tags
  }

  relations = {
    single_relations = {
      resourceGroup = port_entity.resource_group.identifier
    }
  }
}

resource "port_entity" "user_managed_identity" {
  blueprint  = "azureUserManagedIdentity"
  identifier = azurerm_user_assigned_identity.uai.name
  title      = azurerm_user_assigned_identity.uai.name

  properties = {
    clientId = azurerm_user_assigned_identity.uai.client_id
  }

  relations = {
    single_relations = {
      resource_group = port_entity.resource_group.identifier
    }
  }
}

output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}
