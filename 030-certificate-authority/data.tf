data "terraform_remote_state" "compute" {
  backend = "local"

  config = {
    path = "../020-vpc-compute/terraform.tfstate"
  }
}