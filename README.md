# Resource Group Vending

This repository provisions Azure resource groups for lab environments using Terraform.
Environments are provisioned through a GitHub Actions workflow triggered by Port. The workflow runs Terraform with the provided inputs and commits a YAML file under `environments/` containing the configuration and generated resource group id.

## Environment YAML schema
```yaml
environment_name: Demo Environment
environment_short_name: demoenv    # 6-10 chars, no spaces or special characters
location: eastus
environment: dev               # dev | test | prod
port_run_id: abcde12345       # Port action run id
product_name: Demo Product
product_identifier: prod-12345     # product identifier from Port
services: []                       # optional; services can be associated later
```
The `product_name` and `product_identifier` fields record the owning product. Services are associated with an environment later, so `services` may be omitted or left as an empty list.

Managed identities and federated credentials are created automatically by Terraform. The identity is granted Owner access to the resource group and Storage Blob Data Contributor access to the storage account.
The resource group is tagged with the environment name, short name, environment,
GitHub organization and repository so that ownership is clear.

## Provisioning an environment
Port invokes the **Provision Environment** workflow with environment details. On success, the workflow provisions the resources and commits the corresponding YAML file to the repository.

## Associating a service

Run the **Associate Service** workflow to link a service to an environment. It requires the following inputs:

- `environment_identifier` – `<productidentifier>_<environment>_<location>`
- `service_identifier` – unique service id
- `github_repo` – repository in `org/repo` format
- `port_run_id` – Port action run id for this association
- `request_identifier` – Port request that triggered the workflow

The workflow updates the environment manifest with the service information and replaces the `port_run_id` with the supplied value.
After a successful run it also updates the request status to `Configuring Service` in Port.

## Running locally
```bash
terraform -chdir=terraform init
export PORT_CLIENT_ID=<client id>       # Port credentials
export PORT_CLIENT_SECRET=<client secret>
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```
