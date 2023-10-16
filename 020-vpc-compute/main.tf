locals {
  tags = [
    "owner:${var.owner}",
    "provider:ibm",
    "region:${var.region}",
    "deployment:${var.basename}"
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
  count          = 3
  name           = "controller-${count.index}"
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
    name = "controller-${count.index}-vol"
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
  count          = 3
  name           = "worker-${count.index}"
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
    name = "worker-${count.index}-vol"
  }

  primary_network_interface {
    subnet            = data.terraform_remote_state.vpc.outputs.subnet_id
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [data.terraform_remote_state.vpc.outputs.cluster_security_group_id]
  }

  user_data = templatefile("${path.module}/workers.tftpl", {
  pod_cidr = "10.200.${count.index}.0/24" })

  zone = local.vpc_zones[0].zone
  keys = [data.ibm_is_ssh_key.sshkey.id]
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_lb" "apiserver" {
  name           = "${var.basename}-apiserver-lb"
  subnets        = [data.terraform_remote_state.vpc.outputs.subnet_id]
  profile        = "network-fixed"
  type           = "public"
  resource_group = data.terraform_remote_state.vpc.outputs.resource_group_id
  tags           = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_lb_listener" "apiserver_listener" {
  lb       = ibm_is_lb.apiserver.id
  port     = "6443"
  protocol = "tcp"
}

resource "ibm_is_lb_pool" "apiserver_pool" {
  lb                  = ibm_is_lb.apiserver.id
  name                = "${var.basename}-apiserver-pool"
  protocol            = "tcp"
  algorithm           = "round_robin"
  health_delay        = "5"
  health_retries      = "2"
  health_timeout      = "2"
  health_type         = "tcp"
  health_monitor_port = "6443"
  health_monitor_url  = "/"
  depends_on          = [ibm_is_lb_listener.apiserver_listener]
}

resource "ibm_is_lb_pool_member" "apiserver_pool_member" {
  count     = 3
  lb        = ibm_is_lb.apiserver.id
  pool      = element(split("/", ibm_is_lb_pool.apiserver_pool.id), 1)
  port      = 6443
  target_id = ibm_is_instance.controllers[count.index].id
  weight    = 60
}

module "ansible_inventory" {
  source            = "../040-configure-systems"
  bastion_public_ip = ibm_is_floating_ip.bastion.address
  controllers       = ibm_is_instance.controllers.*
  workers           = ibm_is_instance.workers.*
  load_balancer_ip  = ibm_is_lb.apiserver.public_ips[0]
}

resource "local_file" "worker_csr" {
  count    = 3
  content  = <<EOF
{
  "CN": "system:node:worker-${count.index}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Houston",
      "O": "system:nodes",
      "OU": "Kubernetes The Slightly Difficult Way",
      "ST": "Texas"
    }
  ]
}
EOF
  filename = "../030-certificate-authority/worker-${count.index}-csr.json"
}
