output "controller_private_ip" {
  value = ibm_is_instance.controllers[*].primary_network_interface[0].primary_ip[0].address
}

output "workers_private_ip" {
  value = ibm_is_instance.workers[*].primary_network_interface[0].primary_ip[0].address
}

output "controller_name" {
  value = ibm_is_instance.controllers[*].name
}

output "loadbalancer_fqdn" {
  value = "api.${var.basename}.lab"
}

output "pdns_domain" {
  value = "${var.basename}.lab"
}

output "worker_name" {
  value = ibm_is_instance.workers[*].name
}
