# Resource Group Vending

This repository provisions Azure resource groups for lab workloads using Terraform. 
Workloads are provisioned through a GitHub Actions workflow triggered by Port. The workflow runs Terraform with the provided inputs and commits a YAML file under `workloads/` containing the configuration and generated resource group id.

## Workload YAML schema
```yaml
workload_name: Demo Workload
workload_short_name: demowk    # 6-10 chars, no spaces or special characters
location: eastus
network_size: small            # small | medium | large
environment: dev               # dev | test | prod
service_identifier: svc-12345  # service identifier from Port
github:
  org: my-org
  repo: resource-group-vending
  entity: environment          # environment | branch | tag | pull_request
  entity_name: demowk          # e.g. environment name
```

Managed identities and federated credentials are created automatically by Terraform.
The resource group is tagged with the workload name, short name, environment,
GitHub organization and repository so that ownership is clear.

## Provisioning a workload
Port invokes the **Provision Workload** workflow with workload details. On success, the workflow provisions the resources and commits the corresponding YAML file to the repository.

## Running locally
```bash
terraform -chdir=terraform init
export PORT_CLIENT_ID=<client id>       # Port credentials
export PORT_CLIENT_SECRET=<client secret>
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```
