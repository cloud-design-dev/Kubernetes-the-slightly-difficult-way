# Kubernetes the *slightly less difficult way

Borrowing heavily from the original [Kubernetes the Hard Way][kubes-hard-way] guide by [Kelsey Hightower][kelsey-hightower], this tutorial will walk you through the steps of deploying a Kubernetes cluster in an [IBM Cloud VPC][ibm-cloud] using [Terraform][terraform], [Ansible][ansible] and some CLI magic.

The original guide is a great way to get started with Kubernetes and understand the various components that make up the cluster, however, it is a bit dated and uses Google Cloud Platform (GCP) as the cloud provider. I enjoy all things automation, so I wanted to take a stab at a more automated approach, while still covering the various components and steps required to bootstrap your a cluster the **hard way**.

## Overview

The guide is broken down into the following steps:

1. Deploy VPC, network, and compute resources for a kubernetes cluster (3 control plane nodes and 3 worker nodes, load balancer, security groups, etc.)
2. Generate the Kubernetes certificates and kubeconfig files using `cfssl` and `kubectl`
3. Deploy the Kubernetes control plane nodes and etcd cluster
4. Deploy the Kubernetes worker nodes and bootstrap them to the control plane
5. Install DNS Add-on and run some basic `smoke tests` against the cluster

## Pre-requisites

- [IBM Cloud API Key][ibm-cloud-api-key]
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
bastion_security_group_id = "r038-48afbe99-xxxxx"
cluster_security_group_id = "r038-cde50195-xxxxx"
resource_group_id = "ac83304bxxxxx"
subnet_id = "02q7-f36019a5-7035-xxxxx"
vpc_crn = "crn:v1:bluemix:public:is:ca-tor:a/xxxxx::vpc:xxxxx"
vpc_default_routing_table_id = "r038-07087206-2052-xxxxx"
vpc_id = "r038-3542898c-xxxxx"
```

### Step 2: Deploy the compute resources

```shell
(cd 020-vpc-compute && ./main.sh apply)
```

When prompted, enter `yes` to confirm the deployment. When the deployment completes you should see output similar to the following:

### Step 3: Create our certificate authority and genererate keys and certs

```shell
(cd 030-certificate-authority && ./main.sh apply)
```

This terraform run does not contain any output, so once it completes you can move on to running the Ansible playbooks. 

### Step 4: Run Ansible playbooks to prep worker and control plane nodes

The `update-systems.yml` playbook does the following:

 - Updates the `/etc/hosts` file on each instance with all the worker and control plane nodes
 - Runs an `apt-get` update and upgrade of any existing packages.
 - Installs `socat, conntrack, and ipset` on the worker nodes
 - ....

```shell
ansible-playbook -i 040-configure-systems/inventory.ini 040-configure-systems/playbooks/update-systems.yml
```


[kelsey-hightower]: https://en.wikipedia.org/wiki/Kelsey_Hightower
[ibm-cloud]: https://cloud.ibm.com/docs/vpc?topic=vpc-about-vpc
[ibm-cloud-api-key]: https://cloud.ibm.com/docs/account?topic=account-userapikey#create_user_key
[terraform]: https://www.terraform.io/downloads.html
[ansible]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
[kubes-hard-way]: https://github.com/kelseyhightower/kubernetes-the-hard-way
