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
    pod_cidr = "10.200.${count.index}.0/24"
  })

  zone = local.vpc_zones[0].zone
  keys = [data.ibm_is_ssh_key.sshkey.id]
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_vpc_routing_table_route" "pod_cidrs" {
  count         = 3
  vpc           = data.terraform_remote_state.vpc.outputs.vpc_id
  routing_table = data.terraform_remote_state.vpc.outputs.vpc_default_routing_table_id
  zone          = local.vpc_zones[0].zone
  name          = "worker-${count.index}-pod-cidr-route"
  destination   = "10.200.0.${count.index}/24"
  action        = "deliver"
  next_hop      = ibm_is_instance.workers[count.index].primary_network_interface[0].primary_ipv4_address
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

module "ansible_inventory" {
  source            = "../040-configure-systems"
  bastion_public_ip = ibm_is_floating_ip.bastion.address
  controllers       = ibm_is_instance.controllers.*
  workers           = ibm_is_instance.workers.*
  load_balancer_ip  = "api.cde.lab"
}


resource "ibm_resource_instance" "project_instance" {
  name              = "${var.basename}-dns-instance"
  resource_group_id = data.terraform_remote_state.vpc.outputs.resource_group_id
  location          = "global"
  service           = "dns-svcs"
  plan              = "standard-dns"
}

resource "ibm_dns_zone" "kubernetes" {
  name        = "gh40.lab"
  instance_id = ibm_resource_instance.project_instance.guid
  description = "Private DNS Zone for VPC K8s cluster."
  label       = "k8sthehardway"
}

resource "ibm_dns_permitted_network" "permitted_network" {
  instance_id = ibm_resource_instance.project_instance.guid
  zone_id     = ibm_dns_zone.kubernetes.zone_id
  vpc_crn     = data.terraform_remote_state.vpc.outputs.vpc_crn
  type        = "vpc"
}

resource "ibm_dns_resource_record" "controllers" {
  count       = 3
  instance_id = ibm_resource_instance.project_instance.guid
  zone_id     = ibm_dns_zone.kubernetes.zone_id
  type        = "A"
  name        = "controller-${count.index}"
  rdata       = ibm_is_instance.controllers[count.index].primary_network_interface[0].primary_ipv4_address
  ttl         = 3600
}

resource "ibm_dns_resource_record" "workers" {
  count       = 3
  instance_id = ibm_resource_instance.project_instance.guid
  zone_id     = ibm_dns_zone.kubernetes.zone_id
  type        = "A"
  name        = "worker-${count.index}"
  rdata       = ibm_is_instance.workers[count.index].primary_network_interface[0].primary_ipv4_address
  ttl         = 3600
}

resource "ibm_dns_glb_monitor" "gslb_healthcheck" {
  depends_on     = [ibm_dns_zone.kubernetes]
  name           = "${var.basename}-glb-monitor"
  instance_id    = ibm_resource_instance.project_instance.guid
  description    = "Private DNS health check for kubes apiservers"
  interval       = 60
  retries        = 3
  timeout        = 5
  port           = 6443
  type           = "TCP"
}

resource "ibm_dns_glb_pool" "k8s_pdns_glb_pool" {
  depends_on                = [ibm_dns_zone.kubernetes]
  name                      = "${var.basename}-glb-pool"
  instance_id               = ibm_resource_instance.project_instance.guid
  enabled                   = true
  healthy_origins_threshold = 1
  origins {
    name        = "controller-1"
    address     = ibm_is_instance.controllers[0].primary_network_interface[0].primary_ipv4_address
    enabled     = true
  }
  origins {
    name        = "controller-2"
    address     = ibm_is_instance.controllers[0].primary_network_interface[0].primary_ipv4_address
    enabled     = true
  }
    origins {
    name        = "controller-3"
    address     = ibm_is_instance.controllers[0].primary_network_interface[0].primary_ipv4_address
    enabled     = true
  }
  monitor              = ibm_dns_glb_monitor.gslb_healthcheck.monitor_id
  healthcheck_region   = var.region
  healthcheck_subnets  = [data.terraform_remote_state.vpc.outputs.subnet_id]
}


resource "ibm_dns_glb" "k8s_pdns_glb" {
  depends_on    = [ibm_dns_glb_pool.k8s_pdns_glb_pool]
  name          = "${var.basename}-glb"
  instance_id   = ibm_resource_instance.project_instance.guid
  zone_id       = ibm_dns_zone.kubernetes.zone_id
  ttl           = 120
  enabled       = true
  fallback_pool = ibm_dns_glb_pool.k8s_pdns_glb_pool.pool_id
  default_pools = [ibm_dns_glb_pool.k8s_pdns_glb_pool.pool_id]
}

