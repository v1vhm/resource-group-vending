#!/usr/bin/env bash
set -euo pipefail

# Inputs
PRODUCT_NAME="${1:-}"
PRODUCT_SHORT_NAME="${2:-}"
LOCATION="${3:-}"
ENVIRONMENT="${4:-}"
PRODUCT_IDENTIFIER="${5:-}"

if [[ -z "$PRODUCT_NAME" || -z "$PRODUCT_SHORT_NAME" || -z "$LOCATION" || -z "$ENVIRONMENT" || -z "$PRODUCT_IDENTIFIER" ]]; then
  echo "Usage: $0 <product_name> <product_short_name> <location> <environment> <product_identifier>"
  exit 1
fi

# Derived variables
ENVIRONMENT_IDENTIFIER="$(echo "${PRODUCT_NAME}_${ENVIRONMENT}_${LOCATION}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
ENVIRONMENT_TITLE="${PRODUCT_NAME} ${ENVIRONMENT}"
ENV_FILE="environments/${PRODUCT_SHORT_NAME}_${ENVIRONMENT}_${LOCATION}.yaml"
CONTAINER_NAME="$(echo "${PRODUCT_SHORT_NAME}${ENVIRONMENT}${LOCATION}" | tr '[:upper:]' '[:lower:]' | tr ' _' '-')"
STATE_FILE_KEY="${PRODUCT_IDENTIFIER}_${ENVIRONMENT}_${LOCATION}.tfstate"

export TF_VAR_environment_file="$PWD/$ENV_FILE"
export CONTAINER_NAME="$CONTAINER_NAME"
export TF_VAR_port_run_id=""
export ARM_SUBSCRIPTION_ID="da7f852b-9a37-4283-a8c0-de1dafd6cb1f"

# Terraform Init
echo "==> Running terraform init"
terraform -chdir=terraform init \
  -backend-config="resource_group_name=v1vhm-rg-vending-prod-uks-001" \
  -backend-config="storage_account_name=vendingtfstate" \
  -backend-config="container_name=${CONTAINER_NAME}" \
  -backend-config="key=${STATE_FILE_KEY}" \
  -reconfigure | tee terraform-init.log

# Terraform Plan
echo "==> Running terraform plan"
./scripts/terraform-run.sh plan tfplan plan.log
echo "==> Plan log:"
cat plan.log

# Terraform Apply
echo "==> Running terraform apply"
./scripts/terraform-run.sh apply tfplan apply.log
echo "==> Apply log:"
cat apply.log

# Show outputs
echo "==> Terraform outputs"
terraform -chdir=terraform output -json | tee tfoutput.json

echo "==> Done"