#!/bin/bash
set -e -o pipefail

if [[ "$1" == "apply" ]]; then
  tfswitch || true
  (cd 010-vpc-infrastructure && ./main.sh apply)
  (cd 020-vpc-compute && ./main.sh apply)
fi

if [[ "$1" == "destroy" ]]; then
  (cd 020-vpc-compute && ./main.sh destroy) || true
  (cd 010-vpc-infrastructure && ./main.sh destroy) || true
fi

if [[ "$1" == "clean" ]]; then
  (cd 020-infrastructure && ./main.sh clean) || true
  (cd 010-vpc-infrastructure && ./main.sh clean) || true
fi
