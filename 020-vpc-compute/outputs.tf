output "controller_private_ip" {
  value = ibm_is_instance.controllers[*].primary_network_interface[0].primary_ipv4_address
}

output "workers_private_ip" {
  value = ibm_is_instance.workers[*].primary_network_interface[0].primary_ipv4_address
}

output "controller_name" {
  value = ibm_is_instance.controllers[*].name
}

#output "load_balancer_ip" {
#  value = ibm_is_lb.apiserver.public_ips[0]
#}

output "load_balancer_ip" {
  value = "api.cde.lab"
}

output "worker_name" {
  value = ibm_is_instance.workers[*].name
}
