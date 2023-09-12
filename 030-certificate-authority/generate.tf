resource "null_resource" "certificate-authority" {
  provisioner "local-exec" {
    command = "/opt/homebrew/bin/cfssl gencert -initca ca-csr.json | cfssljson -bare ca"
  }
}

