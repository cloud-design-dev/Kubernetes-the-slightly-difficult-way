output "vpc_id" {
  value = ibm_is_vpc.vpc.id
}

output "vpc_crn" {
  value = ibm_is_vpc.vpc.crn
}

output "subnet_id" {
  value = ibm_is_subnet.cluster_subnet.id
}

output "bastion_security_group_id" {
  value = module.bastion_security_group.security_group_id[0]
}

output "cluster_security_group_id" {
  value = module.cluster_security_group.security_group_id[0]
}

output "resource_group_id" {
  value = module.resource_group.resource_group_id
}

output "vpc_default_routing_table_id" {
  value = ibm_is_vpc.vpc.default_routing_table
}