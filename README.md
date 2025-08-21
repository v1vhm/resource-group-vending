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
vending_state_container: envstate-prod-12345-dev-eastus
services:
  - service_identifier: my-service
    deployment_state_container: my-service
    github:
      repository: org/my-service-repo
deployment_environment: /subscriptions/.../resourceGroups/rg-prod-12345-dev-eastus
deployment_identity: /subscriptions/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-prod-12345-dev-eastus
azure_subscription: /subscriptions/...      # subscription id
```

The `status` line records the workflow's progress: it starts as `in_progress` and is later set to `succeeded` or `failed`. The `product_name` and `product_identifier` fields record the owning product.

`vending_state_container` holds the Terraform state for the environment itself. The provisioning workflow creates this container in the shared `vendingtfstate` storage account before Terraform runs, using the name `envstate-<product_short_name>-<environment>-<location>`.

Services are associated with an environment later, so `services` may be omitted or left as an empty list. When services are listed, Terraform provisions a storage container in the environment's storage account for each `service_identifier`. Each container is named exactly after the `service_identifier`, recorded under `deployment_state_container`, and used by that service's deployments. Terraform also configures a GitHub OIDC federated credential for that service. The root module upserts a Port `azureStorageContainer` entity for every deployment state container.

The fields `deployment_environment`, `deployment_identity` and `azure_subscription` are appended after provisioning and are used to create the Port environment entity outside of Terraform. The file is committed when created, updated with outputs and finalized with the workflow result.

Managed identities and federated credentials are created automatically by Terraform. The identity is granted Owner access to the resource group and Storage Blob Data Contributor access to the storage account. The resource group is tagged with the environment, product identifier and product name, GitHub organization and repository so that ownership is clear.

## Terraform modules and outputs

The root Terraform configuration instantiates a single module under
`terraform/modules/resource_group` that is responsible only for
provisioning Azure infrastructure. For each service in the environment
manifest the module provisions a storage container named after the
`service_identifier` and configures a GitHub OIDC federated
credential. The module exposes detailed attributes for each resource,
including:

- `resource_group_*` values for the resource group
- `storage_account_*` values
- `deployment_state_containers` mapping for per-service storage containers
- `user_managed_identity_*` values for the identity

`terraform/main.tf` consumes these outputs to register Port entities for the
resource group, storage account, each deployment state container (using the
`azureStorageContainer` blueprint) and the user-managed identity, then
returns high‑level values used by the GitHub Actions workflow:

- `deployment_environment` – the resource group id
- `deployment_identity` – the user managed identity id
- `azure_subscription` – the subscription id
- `user_managed_identity_client_id`

Port entities are created in the root configuration; the module itself
does not interact with Port.

## Conventions

All Azure resource IDs referenced in environment files or Port relations must be lowercase. Storage account names use the pattern `v1vhm<product_identifier><environment><location>` to ensure global uniqueness. Provisioning state containers live in the shared `vendingtfstate` storage account and are named `envstate-<product_short_name>-<environment>-<location>`. Deployment state containers are created in the environment's storage account and use each `service_identifier` as the container name.

## Provisioning an environment
Port invokes the **Provision Environment** workflow with environment details. The workflow writes the environment file and commits it immediately so that subsequent jobs read the committed file rather than workflow artifacts. It also creates the provisioning state container (`vending_state_container`) in the shared `vendingtfstate` storage account using the `envstate-<product_short_name>-<environment>-<location>` naming pattern and records it in the file. The file itself is named `<product_short_name>_<environment>_<location>.yaml` in lowercase. On success, the workflow provisions the resources and updates the same file with outputs and a final status.

## Associating a service

Run the **Associate Service** workflow to link a service to an environment. It requires the following inputs:

- `environment_identifier` – `<product_identifier>_<environment>_<location>` in lower case with spaces replaced by underscores
- `service_identifier` – unique service id
- `github_repo` – repository in `org/repo` format
- `port_run_id` – Port action run id for this association
- `request_identifier` – Port request that triggered the workflow

The workflow updates the environment manifest with the service information and replaces the `port_run_id` with the supplied value. Terraform provisions a deployment state container in the environment's storage account named after `service_identifier` and records its id under `deployment_state_container`.
After a successful run it also updates the request status to `Configuring Service` in Port.

## Running locally
```bash
terraform -chdir=terraform init
export PORT_CLIENT_ID=<client id>       # Port credentials
export PORT_CLIENT_SECRET=<client secret>
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```
