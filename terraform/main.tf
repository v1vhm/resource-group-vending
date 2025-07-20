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

locals {
  workload_files = fileset("${path.module}/../workloads", "*.yaml")
  workloads = {
    for file in local.workload_files :
    trimsuffix(basename(file), ".yaml") => yamldecode(file("${path.module}/../workloads/${file}"))
  }
}

module "workloads" {
  source   = "./modules/resource_group"
  for_each = local.workloads

  workload_name       = each.value.workload_name
  workload_short_name = each.value.workload_short_name
  location            = each.value.location
  network_size        = each.value.network_size
  environment         = each.value.environment
  github_org          = each.value.github.org
  github_repo         = each.value.github.repo
  github_entity       = each.value.github.entity
  github_entity_name  = each.value.github.entity_name
}
