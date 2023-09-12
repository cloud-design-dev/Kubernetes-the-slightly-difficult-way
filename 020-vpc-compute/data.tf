data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../010-vpc-infrastructure/terraform.tfstate"
  }
}

data "ibm_is_zones" "regional" {
  region = var.region
}

data "ibm_is_image" "base" {
  name = var.image_name
}

data "ibm_is_ssh_key" "sshkey" {
  name = var.existing_ssh_key
}