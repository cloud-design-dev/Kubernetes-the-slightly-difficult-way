# Kubernetes-the-slightly-difficult-way

Borrowing heavily from the original [Kubernetes the Hard Way][kubes-hard-way] guide by [Kelsey Hightower][kelsey-hightower], this guide will walk you through the steps of deploying a Kubernetes cluster in an [IBM Cloud][ibm-cloud] VPC using [Terraform][terraform], [Ansible][ansible] and some CLI magic.

## Pre-requisites

- [IBM Cloud API Key][ibm-cloud-api-key]
- [IBM Cloud CLI][ibm-cloud-cli]
- [Terraform][terraform]
- [Ansible][ansible]
- [cfssl](https://github.com/cloudflare/cfssl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)

## Project Structure

The project is broken down into the following directories:

- `010-vpc-infrastructure` - Terraform code to deploy the IBM VPC and associated networking components
- `020-vpc-compute` - Terraform code to deploy the compute resources in the VPC. This covers the control plane and worker nodes as well as a bastion host for accessing the cluster and running our Ansible playbooks.
- `030-certificate-authority` - Use cfssl to generate the certificate authority and client certificates for the cluster components, kubeconfig files and the Kubernetes API server certificate.
- `040-configure-systems` - Ansible playbooks to deploy the Kubernetes control plane and worker nodes.

## Getting Started

1. Clone the repository
  
  ```shell
   git clone https://github.com/cloud-design-dev/Kubernetes-the-slightly-difficult-way.git
   cd Kubernetes-the-slightly-difficult-way
  ```

2. Copy `template.local.env` to `local.env`:

  ```shell
  cp template.local.env local.env
  ```

3. Edit `local.env` to match your environment.

### Step 1: Deploy VPC and associated networking components

In this first step we will deploy our IBM Cloud VPC, a Public Gateway, a VPC Subnet, and a Security Group for our cluster.

```shell
source local.env
(cd 010-vpc-infrastructure && ./main.sh apply)
```

When prompted, enter `yes` to confirm the deployment. When the deployment completes you should see output similar to the following:

```shell

```

### Step 2: Deploy the compute resources



[ibm-cloud-api-key]: https://cloud.ibm.com/docs/account?topic=account-userapikey#create_user_key
[ibm-cloud-cli]: https://cloud.ibm.com/docs/cli?topic=cli-getting-started
[terraform]: https://www.terraform.io/downloads.html
[ansible]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
[kubes-hard-way]: https://github.com/kelseyhightower/kubernetes-the-hard-way