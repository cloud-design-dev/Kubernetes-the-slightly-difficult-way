resource "local_file" "ansible-inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl",
    {
      bastion_ip  = var.bastion_public_ip
      controllers = var.controllers
      workers     = var.workers
    }
  )
  filename = "${path.module}/inventory.ini"
}

resource "local_file" "ansible-vars" {
  content = templatefile("${path.module}/templates/vars.tmpl",
    {
      loadbalancer_fqdn = var.loadbalancer_fqdn
    }
  )
  filename = "${path.module}/playbooks/vars.yml"
}