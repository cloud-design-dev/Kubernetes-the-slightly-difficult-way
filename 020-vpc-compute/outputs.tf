output "controller_private_ip" {
  value = ibm_is_instance.controllers[*].primary_network_interface[0].primary_ipv4_address
}

output "workers_private_ip" {
  value = ibm_is_instance.workers[*].primary_network_interface[0].primary_ipv4_address
}

output "controller_name" {
  value = ibm_is_instance.controllers[*].name
}

output "load_balancer_ip" {
  value = ibm_is_lb.apiserver.private_ip[0].address
}

output "worker_name" {
  value = ibm_is_instance.workers[*].name
}
