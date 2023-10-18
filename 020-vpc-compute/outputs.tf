output "controller_private_ip" {
  value = ibm_is_instance.controllers[*].primary_network_interface[0].primary_ipv4_address
}

output "workers_private_ip" {
  value = ibm_is_instance.workers[*].primary_network_interface[0].primary_ipv4_address
}

output "controllers" {
  value = ibm_is_instance.controllers[*]
}

# output "lb_public_ip" {
#   value = ibm_is_lb.apiserver.public_ips[0]
# }

output "workers" {
  value = ibm_is_instance.workers[*]
}