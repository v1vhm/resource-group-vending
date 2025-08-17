# Resource Group Vending

This repository provisions Azure resource groups for lab environments using Terraform.
Environments are provisioned through a GitHub Actions workflow triggered by Port. The workflow runs Terraform with the provided inputs and commits a YAML file under `environments/` containing the configuration and identifiers for the created resources.

## Environment YAML schema
```yaml
environment_identifier: demo_product_dev_eastus
environment_title: Demo Product dev
location: eastus
environment: dev               # dev | test | prod | acct
port_run_id: abcde12345       # Port action run id
product_name: Demo Product
product_identifier: prod-12345     # product identifier from Port
services: []                       # optional; services can be associated later
deployment_environment: /subscriptions/.../resourceGroups/rg-prod-12345-dev-eastus
deployment_identity: /subscriptions/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-prod-12345-dev-eastus
azure_subscription: /subscriptions/...      # subscription id
state_file_container: /subscriptions/.../storageAccounts/vendingtfstate/blobServices/default/containers/prod-12345dev
```
The `product_name` and `product_identifier` fields record the owning product. Services are associated with an environment later, so `services` may be omitted or left as an empty list. The fields `deployment_environment`, `deployment_identity`, `azure_subscription` and `state_file_container` are appended after provisioning and are used to create the Port environment entity outside of Terraform.

Managed identities and federated credentials are created automatically by Terraform. The identity is granted Owner access to the resource group and Storage Blob Data Contributor access to the storage account. The resource group is tagged with the environment, product identifier and product name, GitHub organization and repository so that ownership is clear.

## Provisioning an environment
Port invokes the **Provision Environment** workflow with environment details. On success, the workflow provisions the resources and commits the corresponding YAML file to the repository.

## Associating a service

Run the **Associate Service** workflow to link a service to an environment. It requires the following inputs:

- `environment_identifier` – `<product_name>_<environment>_<location>` in lower case with spaces replaced by underscores
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
