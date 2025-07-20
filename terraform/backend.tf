terraform {
  backend "azurerm" {
    resource_group_name  = "v1vhm-rg-vending-prod-uks-001"
    storage_account_name = "vendingtfstate"
    container_name       = "tf-state"
    key                  = "terraform.tfstate"
  }
}
