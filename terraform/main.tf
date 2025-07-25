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

provider "port" {
  # Credentials are read from PORT_CLIENT_ID and PORT_CLIENT_SECRET
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
  service_identifier  = each.value.service_identifier
  github_org          = each.value.github.org
  github_repo         = each.value.github.repo
  github_entity       = each.value.github.entity
  github_entity_name  = each.value.github.entity_name
}

resource "port_entity" "environment" {
  for_each = local.workloads

  blueprint  = "environment"
  identifier = "${each.value.service_identifier}_${each.value.environment}"
  title      = "${each.value.service_identifier}-${each.value.environment}"

  relations = {
    single_relations = {
      workload = "${each.value.workload_name}_${each.value.environment}"
    }
  }
}
