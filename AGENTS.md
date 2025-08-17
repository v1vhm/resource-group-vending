# Guidelines for AI‐assisted development

This repository provisions Azure resource groups for lab or test environments using Terraform.  It is driven by a GitHub Actions workflow that is triggered by Port and commits YAML configuration files under the `environments/` directory.  Each environment file defines metadata (identifier, title, location, environment tier, Port run id, product name and identifier, and optionally a list of associated services).  The workflow then uses Terraform modules to create a resource group, storage account and user‑assigned identity in Azure, tags the resources, registers them with Port and updates the environment file with the resulting identifiers such as the resource group id, identity id and subscription.

The goal of this guide is to help **Codex**, or any automated agent, make changes to the repository confidently and consistently.  It captures conventions, file structures and recent lessons learned so that future pull requests remain coherent.  Before making changes, read this document and the repository’s `README.md` to ensure you understand how the pieces fit together.

## This file

This is a living document - it should evolve as the repository revolves. You **must** consider if any changes to this file are required as part of any request made, and if changes are required, they should be proposed alongside any other changes to this codebase.

## Repository structure and responsibilities

The high‑level layout is:

| Directory/file                      | Purpose |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/workflows/provision.yml`   | GitHub Actions workflow that provisions environments.  It accepts inputs such as `product_name`, `product_short_name`, `location`, `environment`, `product_identifier` and a JSON‑encoded `port_context`.  The workflow creates a YAML file under `environments/`, commits it, creates a dedicated Terraform state container, runs Terraform `init`/`plan`/`apply` and appends Terraform outputs back into the YAML file. Services can be associated later via a separate workflow. |
| `environments/`                     | Contains one YAML file per environment.  These files follow the schema described in the README: `environment_identifier`, `environment_title`, `location`, `environment` (dev/test/prod/acct), `port_run_id`, `product_name`, `product_identifier` and an optional `services` list with `service_identifier` and `github` details for each service.  Workflows and Terraform read these files to provision resources and attach services. |
| `terraform/`                        | Root Terraform configuration.  It uses a local variable to read all YAML files in the `environments` folder and creates a `module` instance for each environment.  It processes any services listed for association and outputs deployment details. |
| `terraform/modules/resource_group/` | Module that creates the Azure resource group, storage account and user‑managed identity.  It names resources using the pattern `rg-${var.product_identifier}-${var.environment}-${var.location}`, sets tags based on the YAML properties and creates a federated credential for GitHub Actions. |

## Naming conventions and data contracts

* **YAML schema:** The environment YAML schema in the README shows the expected keys and constraints, including `environment_identifier` and `environment_title`. `environment` must be one of `dev`, `test`, `prod` or `acct`, and each file includes `product_name` and `product_identifier`.  The optional `services` list contains entries with the unique `service_identifier` and GitHub details for each service when present.  When creating new environment files, adhere to this schema.
* **File names:** Environment files are named `${product_short_name}_${environment}_${location}.yaml`.  The workflow uses the short name and environment tier to build this file name and related resource names.  Do not include spaces or uppercase letters in file names.  The workflow also uses `${product_short_name}_${environment}_${location}` for the state container name and YAML file inside the job, so ensure the values are valid for Azure storage container naming (lowercase alphanumeric and hyphens; length ≤ 63 characters).
* **Terraform state:** A recent change introduced a separate state file per environment (see commit message *"Create a new state file for each environment"*).  If adding new environments or modifying the backend configuration, keep this behaviour by using a unique `key` in `backend.tf` (e.g., `${product_identifier}_${environment}_${location}.tfstate`).  Avoid using a single shared `terraform.tfstate` for all environments.
* **Port entities:** The Terraform root registers a Port *environment* entity using the `product_identifier`, environment tier and location as the identifier and title.  Do not revert to using the short name here; a recent commit corrected this (see commit *"port objects now use correct identifier"*).  When adding properties or relations to Port entities, ensure that identifiers remain stable (changing them will orphan existing records).  Services relate to this entity through the optional `services` list.
* **Use IDs for relations:** Another recent change switched from using resource names to Azure IDs when passing values back to Port (see commit *"Changing resource name properties to id properties"*).  When adding new outputs or relations, prefer IDs over names; IDs are globally unique and avoid collisions.

## Making changes to the workflow

When editing `.github/workflows/provision.yml` or adding new workflows:

1. **Inputs and environment variables:** Maintain the current input set (`product_name`, `product_short_name`, `location`, `environment`, `product_identifier`, `port_context`).  If you add a new required parameter, update the workflow dispatch inputs and document it in the README.  Services are associated later using a dedicated workflow.
2. **Environment file creation:** The step labelled *Create environment file* writes the YAML file using the input values and the Port run id, adding product metadata but leaving the `services` list empty.  If you modify the YAML schema, update this step accordingly.  Remember to keep YAML indentation consistent (two spaces per level) so that `yamldecode()` in Terraform can parse it; the current files omit some indentation which still works but is less readable.  Consider generating well‑indented YAML when you modify this step.
3. **Commit messages:** The workflow commits with messages like `Add environment <short_name>_<environment>` and later `Update environment <short_name>_<environment> with outputs`.  When changing commit logic, keep concise, imperative commit messages.  The commits are signed by GitHub; no action is required to maintain signatures.
4. **Terraform state container:** The workflow creates an Azure Storage container for each environment using the naming pattern `${product_short_name}_${environment}_${location}`.  If you change the naming scheme, update `backend.tf` and ensure containers are created consistently.  Do not hardcode secrets; use repository secrets for credentials.
5. **Logging to Port:** Many steps call `port-labs/port-github-action` to log messages or mark run status.  If you add new steps that perform long‑running tasks, consider adding a corresponding log entry so that Port users can follow progress.
6. **File paths for Terraform:** Terraform commands run with `-chdir=terraform`. When passing file paths (e.g., the environment YAML) via variables, supply an absolute path so Terraform can locate the file regardless of the current working directory.

### Error handling

Terraform execution in the provisioning workflow is centralized in `scripts/terraform-run.sh`. This helper uses `set -euo pipefail` and a `trap` handler to capture the exit code and emit the collected log back to the step through `$GITHUB_OUTPUT`. Invoke it for Terraform `plan` and `apply` to ensure consistent logging.

Workflow steps that depend on previous steps should explicitly set `if: success()` (e.g., summarizing or uploading the plan). Logging steps that surface errors should use `if: failure()` and reference the failing step's output such as `${{ steps.plan.outputs.log }}` so that problems are visible in Port.

## Updating Terraform

* **Variables and modules:** When adding new fields to the environment YAML schema (e.g., a new tag or property), declare a corresponding variable in `terraform/modules/resource_group/variables.tf` and propagate it through `terraform/main.tf` into the module and resources.  Be consistent: if a variable is optional, give it a default value or use `try()` in the module to avoid errors.
* **Resource naming:** Azure resources have naming rules (storage accounts require globally unique names, 3–24 lowercase alphanumeric characters; resource groups can include alphanumerics, hyphens and underscores).  The module currently concatenates the product identifier, environment and location to form names.  If you change the naming pattern, ensure it remains valid and update all dependent resources and outputs.
* **Outputs:** The resource group module exposes `resource_group_id`, `resource_group_name` and `user_managed_identity_id`.  The root configuration outputs `deployment_environment`, `deployment_identity` and `azure_subscription` so the workflow can record them in the environment file.  When adding new outputs, update the workflow step that appends these values (the step uses `jq` to extract them from `terraform output`).  Maintain JSON parsing rather than relying on string matching.
* **Port integration:** Use the `port_labs` provider to register additional entities or relations.  Keep identifiers stable and avoid changing blueprint names.  When adding relations, ensure the related identifier exists.

## Adding or updating environments

To add a new environment (for example, a new microservice or a new tier for an existing service):

1. Run the **Provision Environment** workflow manually via the GitHub Actions UI or allow Port to trigger it.  Provide appropriate values for all inputs.  The workflow will create a YAML file under `environments/`, create the state container, run Terraform and commit the YAML file and its updates.
2. After the workflow completes, verify that the new YAML file exists under `environments/` and that the `deployment_environment`, `deployment_identity`, `azure_subscription` and `state_file_container` entries were appended.
3. If services need to be associated, run the dedicated service‑association workflow to populate the `services` list.
4. Inspect the Azure portal to confirm that the resource group, storage account and user‑managed identity have been created with the expected names.  Ensure tags reflect the environment metadata.
5. Consider adding unit tests or integration tests (e.g., using `terraform validate` or `terraform plan` in CI) to prevent regressions.

## Recent lessons learned

* Creating a unique Terraform state file for each environment avoids concurrency problems and makes it possible to manage environments independently.  If you see a single `terraform.tfstate` referenced anywhere, refactor it to use per‑environment keys.
* Using each `service_identifier` (not the short name) as the Port entity identifier prevents collisions across services and better reflects Port’s data model.
* Passing resource **ids** instead of names into Port properties and relations makes the integration more robust.  Avoid relying on human‑readable names in relations.
* Commit messages should clearly describe the action performed; for example, “Add environment mnms01_dev” when introducing a new environment.  This helps with audit trails and automation.

## Things to avoid

* **Hard‑coding secrets or credentials.** Always read Azure, Port or GitHub credentials from GitHub repository secrets.  The workflow uses `secrets.AZURECLIENTID`, etc.; do not embed these values in the repo.
* **Editing YAML files manually in the repository.** Environment files are generated and updated by the workflow.  Manual edits can break the Terraform parsing logic or drift from the actual infrastructure.  If you must change a value, run the provisioning workflow again with updated inputs.
* **Removing or renaming existing environment files without also destroying the corresponding Azure resources.** Deleting a YAML file does not automatically tear down resources; you must run `terraform destroy` or script the deletion.
* **Changing identifier formats.** Changing how identifiers are built (e.g., switching to names instead of ids) can orphan Port entities and break relations.

By following this guide, Codex and other agents will be able to propose and implement changes that respect the repository’s architecture, naming conventions and integration points.  When in doubt, inspect recent commits for examples (e.g., adding an environment or adjusting identifiers) and consult this document.
