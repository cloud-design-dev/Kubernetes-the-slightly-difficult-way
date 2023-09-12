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