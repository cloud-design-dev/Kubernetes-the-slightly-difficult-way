locals {
  tags = [
    "owner:${var.owner}",
    "provider:ibm",
    "region:${var.region}"
  ]
  zones = length(data.ibm_is_zones.regional.zones)
  vpc_zones = {
    for zone in range(local.zones) : zone => {
      zone = "${var.region}-${zone + 1}"
    }
  }
} 

resource "ibm_is_instance" "bastion" {
  name           = "${var.basename}-bastion"
  vpc            = data.terraform_remote_state.vpc.outputs.vpc_id
  image          = data.ibm_is_image.base.id
  profile        = var.instance_profile
  resource_group = data.terraform_remote_state.vpc.outputs.resource_group_id

  metadata_service {
    enabled            = true
    protocol           = "https"
    response_hop_limit = 5
  }

  boot_volume {
    name = "${var.basename}-bastion"
  }

  primary_network_interface {
    subnet            = data.terraform_remote_state.vpc.outputs.subnet_id
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [data.terraform_remote_state.vpc.outputs.bastion_security_group_id]
  }

  zone = local.vpc_zones[0].zone
  keys = [data.ibm_is_ssh_key.sshkey.id]
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_floating_ip" "bastion" {
  name           = "${var.basename}-bastion-ip"
  resource_group = data.terraform_remote_state.vpc.outputs.resource_group_id
  target         = ibm_is_instance.bastion.primary_network_interface[0].id
  tags           = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_instance" "controllers" {
  count = 3
  name           = "${var.basename}-controller-${count.index}"
  vpc            = data.terraform_remote_state.vpc.outputs.vpc_id
  image          = data.ibm_is_image.base.id
  profile        = var.instance_profile
  resource_group = data.terraform_remote_state.vpc.outputs.resource_group_id

  metadata_service {
    enabled            = true
    protocol           = "https"
    response_hop_limit = 5
  }

  boot_volume {
    name = "${var.basename}-controller-${count.index}-vol"
  }

  primary_network_interface {
    subnet            = data.terraform_remote_state.vpc.outputs.subnet_id
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [data.terraform_remote_state.vpc.outputs.cluster_security_group_id]
  }

  zone = local.vpc_zones[0].zone
  keys = [data.ibm_is_ssh_key.sshkey.id]
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_instance" "workers" {
  count = 3
  name           = "${var.basename}-worker-${count.index}"
  vpc            = data.terraform_remote_state.vpc.outputs.vpc_id
  image          = data.ibm_is_image.base.id
  profile        = var.instance_profile
  resource_group = data.terraform_remote_state.vpc.outputs.resource_group_id

  metadata_service {
    enabled            = true
    protocol           = "https"
    response_hop_limit = 5
  }

  boot_volume {
    name = "${var.basename}-worker-${count.index}-vol"
  }

  primary_network_interface {
    subnet            = data.terraform_remote_state.vpc.outputs.subnet_id
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [data.terraform_remote_state.vpc.outputs.cluster_security_group_id]
  }

  zone = local.vpc_zones[0].zone
  keys = [data.ibm_is_ssh_key.sshkey.id]
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

module "ansible_inventory" {
  source            = "../040-copy-required-files"
  bastion_public_ip = ibm_is_floating_ip.bastion.address
  controllers       = ibm_is_instance.controllers.*
  workers           = ibm_is_instance.workers.*
}