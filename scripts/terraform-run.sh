#!/usr/bin/env bash
set -euo pipefail

cmd=$1
plan_file=$2
log_file=$3

finish() {
  status=$?
  echo "log<<EOF" >> "$GITHUB_OUTPUT"
  cat "$log_file" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
  exit $status
}
trap finish ERR

if [ "$cmd" = "plan" ]; then
  terraform -chdir=terraform plan -out="$plan_file" -no-color 2>&1 | tee "$log_file"
  echo "path=$plan_file" >> "$GITHUB_OUTPUT"
elif [ "$cmd" = "apply" ]; then
  terraform -chdir=terraform apply -auto-approve -no-color "$plan_file" 2>&1 | tee "$log_file"
else
  echo "Unsupported command: $cmd" >&2
  exit 1
fi

trap - ERR
finish
