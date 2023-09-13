#!/bin/bash
set -e

if [[ "$1" == "apply" ]]; then
  terraform init
  terraform apply
fi

if [[ "$1" == "destroy" ]]; then
  terraform destroy
  rm -rf .terraform *.csr *.pem
fi

if [[ "$1" == "clean" ]]; then
  rm -rf .terraform .terraform.lock.hcl terraform.tfstate* *.csr *.pem
fi
