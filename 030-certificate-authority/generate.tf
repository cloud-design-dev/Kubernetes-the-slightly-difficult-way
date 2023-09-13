output "vpc_outputs" {
  value = data.terraform_remote_state.compute.outputs.controller_private_ip
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#certificate-authority
resource "null_resource" "certificate-authority" {
  provisioner "local-exec" {
    command = "cfssl gencert -initca ca-csr.json | cfssljson -bare ca"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#client-and-server-certificates
resource "null_resource" "admin_client" {
  depends_on = [null_resource.certificate-authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kubelet-client-certificates
resource "null_resource" "kubelet_client" {
  depends_on = [null_resource.certificate-authority]
  count      = 3
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${data.terraform_remote_state.compute.outputs.workers[count.index].name},${data.terraform_remote_state.compute.outputs.workers_private_ip[count.index]} -profile=kubernetes ${data.terraform_remote_state.compute.outputs.workers[count.index].name}-csr.json | cfssljson -bare ${data.terraform_remote_state.compute.outputs.workers[count.index].name}"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-controller-manager-client-certificate
resource "null_resource" "controller_manager" {
  depends_on = [null_resource.certificate-authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "kube_proxy" {
  depends_on = [null_resource.certificate-authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "kube_scheduler" {
  depends_on = [null_resource.certificate-authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "service_account" {
  depends_on = [null_resource.certificate-authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes service-account-csr.json | cfssljson -bare service-account"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "kube_apiserver" {
  depends_on = [null_resource.certificate-authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=10.32.0.1,${data.terraform_remote_state.compute.outputs.workers_private_ip[0]},${data.terraform_remote_state.compute.outputs.workers_private_ip[1]},${data.terraform_remote_state.compute.outputs.workers_private_ip[2]},${data.terraform_remote_state.compute.outputs.lb_public_ip},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes"

  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_cluster" {
  depends_on = [null_resource.certificate-authority]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${data.terraform_remote_state.compute.outputs.lb_public_ip}:6443 --kubeconfig=${data.terraform_remote_state.compute.outputs.workers[count.index].name}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_creds" {
  depends_on = [null_resource.certificate-authority]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config set-credentials system:node:${data.terraform_remote_state.compute.outputs.workers[count.index].name} --client-certificate=${data.terraform_remote_state.compute.outputs.workers[count.index].name}.pem --client-key=${data.terraform_remote_state.compute.outputs.workers[count.index].name}-key.pem --embed-certs=true --kubeconfig=${data.terraform_remote_state.compute.outputs.workers[count.index].name}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_context" {
  depends_on = [null_resource.certificate-authority]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:${data.terraform_remote_state.compute.outputs.workers[count.index].name} --kubeconfig=${data.terraform_remote_state.compute.outputs.workers[count.index].name}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_default" {
  depends_on = [null_resource.certificate-authority]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config use-context default --kubeconfig=${data.terraform_remote_state.compute.outputs.workers[count.index].name}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kube-proxy-kubernetes-configuration-file

# resource "null_resource" "kube_config_default" {
#   depends_on = [null_resource.certificate-authority]
#   count      = 3
#   provisioner "local-exec" {
#     command = "{
#   kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem \
#     --embed-certs=true \
#     --server=https://${data.terraform_remote_state.compute.outputs.lb_public_ip}:6443 \
#     --kubeconfig=kube-proxy.kubeconfig

#   kubectl config set-credentials system:kube-proxy \
#     --client-certificate=kube-proxy.pem \
#     --client-key=kube-proxy-key.pem \
#     --embed-certs=true \
#     --kubeconfig=kube-proxy.kubeconfig

#   kubectl config set-context default \
#     --cluster=kubernetes-the-hard-way \
#     --user=system:kube-proxy \
#     --kubeconfig=kube-proxy.kubeconfig

#   kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
# }"
#   }
# }


