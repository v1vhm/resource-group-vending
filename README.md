# Resource Group Vending

This repository provisions Azure resource groups for lab workloads using Terraform.
Each workload is described by a YAML file under `workloads/`.

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

## Adding a workload
1. Copy `workloads/demo.yaml` and adjust values.
2. Commit the new file and open a pull request.
3. GitHub Actions will run `terraform plan`.
4. On merge to `main`, the workflow applies the changes and creates the resource group, managed identity, and federated credential.

## Running locally
```bash
terraform -chdir=terraform init
export PORT_CLIENT_ID=<client id>       # Port credentials
export PORT_CLIENT_SECRET=<client secret>
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```
