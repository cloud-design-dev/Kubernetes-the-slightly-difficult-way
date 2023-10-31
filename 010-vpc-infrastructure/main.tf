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

module "bastion_security_group" {
  source                = "terraform-ibm-modules/vpc/ibm//modules/security-group"
  version               = "1.1.1"
  create_security_group = true
  name                  = "${var.basename}-bastion-sg"
  vpc_id                = ibm_is_vpc.vpc.id
  resource_group_id     = module.resource_group.resource_group_id
  security_group_rules  = local.bastion_rules
}

module "controller_security_group" {
  source                = "terraform-ibm-modules/vpc/ibm//modules/security-group"
  version               = "1.1.1"
  create_security_group = true
  name                  = "${var.basename}-cluster-sg"
  vpc_id                = ibm_is_vpc.vpc.id
  resource_group_id     = module.resource_group.resource_group_id
  security_group_rules  = local.cluster_rules
}


resource "ibm_is_security_group_rule" "bastion_to_cluster_ssh" {
  depends_on = [module.bastion_security_group]
  group      = module.cluster_security_group.security_group_id[0]
  direction  = "inbound"
  remote     = module.bastion_security_group.security_group_id[0]
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "cluster_to_cluster" {
  depends_on = [module.cluster_security_group]
  group      = module.cluster_security_group.security_group_id[0]
  direction  = "inbound"
  remote     = module.cluster_security_group.security_group_id[0]
}

resource "ibm_is_security_group_rule" "cluster_nodeport_to_cluster_tcp" {
  depends_on = [module.bastion_security_group]
  group      = module.cluster_security_group.security_group_id[0]
  direction  = "inbound"
  remote     = module.bastion_security_group.security_group_id[0]
  tcp {
    port_min = 30000
    port_max = 32767
  }
}
