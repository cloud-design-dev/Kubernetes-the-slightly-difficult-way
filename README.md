# Kubernetes-the-slightly-difficult-way
Deploy a Kubernetes cluster using terraform, Ansible and some CLI magic

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

4. Deploy VPC and Compute Resources

  ```shell
  (cd 010-vpc-infrastructure && ./main.sh apply)
  (cd 020-vpc-compute && ./main.sh apply)
  ```
