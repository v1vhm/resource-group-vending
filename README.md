# Resource Group Vending

This repository provisions Azure resource groups for lab environments using Terraform.
Environments are provisioned through a GitHub Actions workflow triggered by Port. The workflow runs Terraform with the provided inputs and commits a YAML file under `environments/` containing the configuration and identifiers for the created resources.

## Environment YAML schema
```yaml
environment_identifier: prod-12345_dev_eastus
environment_title: Demo Product dev
location: eastus
environment: dev               # dev | test | prod | acct
status: in_progress        # then succeeded | failed
port_run_id: abcde12345       # Port action run id
product_name: Demo Product
product_identifier: prod-12345     # product identifier from Port
services: []                       # optional; services can be associated later
deployment_environment: /subscriptions/.../resourceGroups/rg-prod-12345-dev-eastus
deployment_identity: /subscriptions/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-prod-12345-dev-eastus
azure_subscription: /subscriptions/...      # subscription id
  state_file_container: v1vhmprod-12345deveastus-tfstate
```
The `status` line records the workflow's progress: it starts as `in_progress` and is later set to `succeeded` or `failed`. The `product_name` and `product_identifier` fields record the owning product. Services are associated with an environment later, so `services` may be omitted or left as an empty list. The fields `deployment_environment`, `deployment_identity`, `azure_subscription` and `state_file_container` are appended after provisioning and are used to create the Port environment entity outside of Terraform. The file is committed when created, updated with outputs and finalized with the workflow result.

Managed identities and federated credentials are created automatically by Terraform. The identity is granted Owner access to the resource group and Storage Blob Data Contributor access to the storage account. The resource group is tagged with the environment, product identifier and product name, GitHub organization and repository so that ownership is clear.

## Terraform modules and outputs

The root Terraform configuration instantiates a single module under
`terraform/modules/resource_group` that is responsible only for
provisioning Azure infrastructure. The module exposes detailed
attributes for each resource, including:

- `resource_group_*` values for the resource group
- `storage_account_*` values and the `state_container_name`/
  `state_file_container`
- `user_managed_identity_*` values for the identity

`terraform/main.tf` consumes these outputs to register Port entities and
then returns high‑level values used by the GitHub Actions workflow:

- `deployment_environment` – the resource group id
- `deployment_identity` – the user managed identity id
- `azure_subscription` – the subscription id
- `state_file_container` – the state container id
- `user_managed_identity_client_id`

Port entities are created in the root configuration; the module itself
does not interact with Port.

## Conventions

All Azure resource IDs referenced in environment files or Port relations must be lowercase. Storage account names use the pattern `v1vhm<product_identifier><environment><location>` to ensure global uniqueness.

## Provisioning an environment
Port invokes the **Provision Environment** workflow with environment details. The workflow writes the environment file and commits it immediately so that subsequent jobs read the committed file rather than workflow artifacts. The file is named `<product_short_name>_<environment>_<location>.yaml` in lowercase. On success, the workflow provisions the resources and updates the same file with outputs and a final status.

## Associating a service

Run the **Associate Service** workflow to link a service to an environment. It requires the following inputs:

- `environment_identifier` – `<product_identifier>_<environment>_<location>` in lower case with spaces replaced by underscores
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
