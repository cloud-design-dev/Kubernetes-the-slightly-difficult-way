module "resource_group" {
  source                       = "git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git?ref=v1.0.5"
  resource_group_name          = var.existing_resource_group == null ? "${var.basename}-resource-group" : null
  existing_resource_group_name = var.existing_resource_group
}

resource "ibm_is_vpc" "vpc" {
  name                        = "${var.basename}-vpc"
  resource_group              = module.resource_group.resource_group_id
  classic_access              = var.classic_access
  address_prefix_management   = var.default_address_prefix
  default_network_acl_name    = "${var.basename}-default-network-acl"
  default_security_group_name = "${var.basename}-default-security-group"
  default_routing_table_name  = "${var.basename}-default-routing-table"
  tags                        = local.tags
}

resource "ibm_is_public_gateway" "dmz_pgw" {
  name           = "${var.basename}-dmz-pgw"
  resource_group = module.resource_group.resource_group_id
  vpc            = ibm_is_vpc.vpc.id
  zone           = local.vpc_zones[0].zone
  tags           = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_subnet" "dmz_subnet" {
  name                     = "${var.basename}-dmz-subnet"
  resource_group           = module.resource_group.resource_group_id
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = local.vpc_zones[0].zone
  total_ipv4_address_count = "128"
  public_gateway           = ibm_is_public_gateway.dmz_pgw.id
  tags                     = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_public_gateway" "cluster_pgw" {
  name           = "${var.basename}-cluster-pgw"
  resource_group = module.resource_group.resource_group_id
  vpc            = ibm_is_vpc.vpc.id
  zone           = local.vpc_zones[1].zone
  tags           = concat(local.tags, ["zone:${local.vpc_zones[1].zone}"])
}

resource "ibm_is_subnet" "controller_subnet" {
  name                     = "${var.basename}-controller-subnet"
  resource_group           = module.resource_group.resource_group_id
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = local.vpc_zones[1].zone
  total_ipv4_address_count = "128"
  public_gateway           = ibm_is_public_gateway.cluster_pgw.id
  tags                     = concat(local.tags, ["zone:${local.vpc_zones[1].zone}"])
}

resource "ibm_is_subnet" "worker_subnet" {
  name                     = "${var.basename}-worker-subnet"
  resource_group           = module.resource_group.resource_group_id
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = local.vpc_zones[1].zone
  total_ipv4_address_count = "128"
  public_gateway           = ibm_is_public_gateway.cluster_pgw.id
  tags                     = concat(local.tags, ["zone:${local.vpc_zones[1].zone}"])
}

module "dmz_security_group" {
  source                = "terraform-ibm-modules/vpc/ibm//modules/security-group"
  version               = "1.1.1"
  create_security_group = true
  name                  = "${var.basename}-dmz-sg"
  vpc_id                = ibm_is_vpc.vpc.id
  resource_group_id     = module.resource_group.resource_group_id
  security_group_rules  = local.dmz_rules
}

module "controller_security_group" {
  source                = "terraform-ibm-modules/vpc/ibm//modules/security-group"
  version               = "1.1.1"
  create_security_group = true
  name                  = "${var.basename}-cluster-sg"
  vpc_id                = ibm_is_vpc.vpc.id
  resource_group_id     = module.resource_group.resource_group_id
  security_group_rules  = local.controller_rules
}

module "worker_security_group" {
  source                = "terraform-ibm-modules/vpc/ibm//modules/security-group"
  version               = "1.1.1"
  create_security_group = true
  name                  = "${var.basename}-worker-sg"
  vpc_id                = ibm_is_vpc.vpc.id
  resource_group_id     = module.resource_group.resource_group_id
  security_group_rules  = local.worker_rules
}

resource "ibm_is_security_group_rule" "bastion_to_controller_ssh" {
  depends_on = [module.dmz_security_group]
  group      = module.controller_security_group.security_group_id[0]
  direction  = "inbound"
  remote     = module.dmz_security_group.security_group_id[0]
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "bastion_to_worker_ssh" {
  depends_on = [module.dmz_security_group]
  group      = module.worker_security_group.security_group_id[0]
  direction  = "inbound"
  remote     = module.dmz_security_group.security_group_id[0]
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "controllers_to_workers_inbound" {
  depends_on = [module.worker_security_group]
  group      = module.worker_security_group.security_group_id[0]
  direction  = "inbound"
  remote     = module.controller_security_group.security_group_id[0]
}

resource "ibm_is_security_group_rule" "controllers_to_workers_outbound" {
  depends_on = [module.worker_security_group]
  group      = module.worker_security_group.security_group_id[0]
  direction  = "outbound"
  remote     = module.controller_security_group.security_group_id[0]
}

resource "ibm_is_instance" "bastion" {
  name           = "${var.basename}-bastion"
  vpc            = ibm_is_vpc.vpc.id
  image          = data.ibm_is_image.base.id
  profile        = var.instance_profile
  resource_group = module.resource_group.resource_group_id

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
  count          = 1
  name           = "controller-${count.index}"
  vpc            = ibm_is_vpc.vpc.id
  image          = data.ibm_is_image.base.id
  profile        = var.instance_profile
  resource_group = module.resource_group.resource_group_id

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
  depends_on     = [ibm_is_instance.controllers]
  count          = 1
  name           = "worker-${count.index}"
  vpc            = ibm_is_vpc.vpc.id
  image          = data.ibm_is_image.base.id
  profile        = var.instance_profile
  resource_group = module.resource_group.resource_group_id

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
    pod_cidr = "172.18.${count.index}.0/16"
  })

  zone = local.vpc_zones[0].zone
  keys = [data.ibm_is_ssh_key.sshkey.id]
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_vpc_routing_table_route" "woker_pod_cidr_route" {
  depends_on    = [ibm_is_instance.workers]
  count         = 1
  vpc           = data.terraform_remote_state.vpc.outputs.vpc_id
  routing_table = data.terraform_remote_state.vpc.outputs.vpc_default_routing_table_id
  zone          = local.vpc_zones[0].zone
  name          = "worker-${count.index}-pod-cidr-route"
  destination   = "172.18.${count.index}.0/16"
  action        = "deliver"
  priority      = 2
  next_hop      = ibm_is_instance.workers[count.index].primary_network_interface[0].primary_ip[0].address
}

resource "ibm_resource_instance" "project_instance" {
  name              = "${var.basename}-dns-instance"
  resource_group_id = data.terraform_remote_state.vpc.outputs.resource_group_id
  location          = "global"
  service           = "dns-svcs"
  plan              = "standard-dns"
  tags              = local.tags
}

resource "ibm_dns_zone" "kubernetes" {
  name        = "${var.basename}.lab"
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
  rdata       = ibm_is_instance.controllers[count.index].primary_network_interface[0].primary_ip[0].address
  ttl         = 3600
}

resource "ibm_dns_resource_record" "workers" {
  count       = 1
  instance_id = ibm_resource_instance.project_instance.guid
  zone_id     = ibm_dns_zone.kubernetes.zone_id
  type        = "A"
  name        = "worker-${count.index}"
  rdata       = ibm_is_instance.workers[count.index].primary_network_interface[0].primary_ip[0].address
  ttl         = 3600
}

resource "ibm_dns_glb_monitor" "gslb_healthcheck" {
  depends_on  = [ibm_dns_zone.kubernetes]
  name        = "${var.basename}-glb-monitor"
  instance_id = ibm_resource_instance.project_instance.guid
  description = "Private DNS health check for kubes apiservers"
  interval    = 60
  retries     = 3
  timeout     = 5
  port        = 6443
  type        = "TCP"
}

resource "ibm_dns_glb_pool" "k8s_pdns_glb_pool" {
  depends_on                = [ibm_dns_zone.kubernetes]
  name                      = "${var.basename}-glb-pool"
  instance_id               = ibm_resource_instance.project_instance.guid
  enabled                   = true
  healthy_origins_threshold = 1

  # look up how to do dynamic based on number of controllers
  origins {
    name    = "controller-0"
    address = ibm_is_instance.controllers[0].primary_network_interface[0].primary_ip[0].address
    enabled = true
  }

  monitor             = ibm_dns_glb_monitor.gslb_healthcheck.monitor_id
  healthcheck_region  = var.region
  healthcheck_subnets = [data.terraform_remote_state.vpc.outputs.subnet_id]
}


resource "ibm_dns_glb" "k8s_pdns_glb" {
  depends_on    = [ibm_dns_glb_pool.k8s_pdns_glb_pool]
  name          = "api.${var.basename}.lab"
  instance_id   = ibm_resource_instance.project_instance.guid
  zone_id       = ibm_dns_zone.kubernetes.zone_id
  ttl           = 120
  enabled       = true
  fallback_pool = ibm_dns_glb_pool.k8s_pdns_glb_pool.pool_id
  default_pools = [ibm_dns_glb_pool.k8s_pdns_glb_pool.pool_id]
}

module "certificate_authority" {
  source            = "./modules/certificate-authority"
  controllers       = ibm_is_instance.controllers.*
  workers           = ibm_is_instance.workers.*
  loadbalancer_fqdn = "api.${var.basename}.lab"
}

module "ansible_inventory" {
  source            = "./modules/ansible"
  bastion_public_ip = ibm_is_floating_ip.bastion.address
  controllers       = ibm_is_instance.controllers.*
  workers           = ibm_is_instance.workers.*
  loadbalancer_fqdn = "api.${var.basename}.lab"
}

