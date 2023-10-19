#!/bin/bash
set -e

if [[ "$1" == "apply" ]]; then
  terraform init
  terraform apply
fi

if [[ "$1" == "destroy" ]]; then
  terraform destroy
fi

if [[ "$1" == "clean" ]]; then
  rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
fi

if [[ "$1" == "auto-approve" ]]; then
  terraform init
  terraform apply -auto-approve
fi