output "vpc_id" {
  value = module.vpc.vpc_id[0]
}

output "subnet_id" {
  value = module.vpc.subnet_ids[0]
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
