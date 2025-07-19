resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.workload_short_name}-${var.environment}"
  location = var.location
  tags = {
    workload_name = var.workload_name
    network_size  = var.network_size
    environment   = var.environment
  }
}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "uai-${var.workload_short_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "owner" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = "fic-${var.workload_short_name}-${var.environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.uai.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_org}/${var.github_repo}:${var.github_entity}:${var.github_entity_name}"
  audiences                 = ["api://AzureADTokenExchange"]
}

output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}
