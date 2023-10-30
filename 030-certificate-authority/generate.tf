resource "local_file" "worker_csr" {
  count    = 3
  content  = <<EOF
{
  "CN": "system:node:worker-${count.index}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Houston",
      "O": "system:nodes",
      "OU": "Kubernetes The Slightly Difficult Way",
      "ST": "Texas"
    }
  ]
}
EOF
  filename = "worker-${count.index}-csr.json"
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#certificate-authority
resource "null_resource" "certificate_authority" {
  depends_on = [local_file.worker_csr]
  provisioner "local-exec" {
    command = "cfssl gencert -initca ca-csr.json | cfssljson -bare ca"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#client-and-server-certificates
resource "null_resource" "admin_client" {
  depends_on = [null_resource.certificate_authority]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kubelet-client-certificates
resource "null_resource" "kubelet_client" {
  depends_on = [null_resource.admin_client]
  count      = 3
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=${data.terraform_remote_state.compute.outputs.worker_name[count.index]},${data.terraform_remote_state.compute.outputs.workers_private_ip[count.index]} -profile=kubernetes ${data.terraform_remote_state.compute.outputs.worker_name[count.index]}-csr.json | cfssljson -bare ${data.terraform_remote_state.compute.outputs.worker_name[count.index]}"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-controller-manager-client-certificate
resource "null_resource" "controller_manager" {
  depends_on = [null_resource.kubelet_client]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "kube_proxy" {
  depends_on = [null_resource.controller_manager]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "kube_scheduler" {
  depends_on = [null_resource.kube_proxy]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "service_account" {
  depends_on = [null_resource.kube_scheduler]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes service-account-csr.json | cfssljson -bare service-account"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md#the-kube-proxy-client-certificate
resource "null_resource" "kube_apiserver" {
  depends_on = [null_resource.service_account]
  provisioner "local-exec" {
    command = "cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=10.32.0.1,${data.terraform_remote_state.compute.outputs.controller_private_ip[0]},${data.terraform_remote_state.compute.outputs.controller_private_ip[1]},${data.terraform_remote_state.compute.outputs.controller_private_ip[2]},${data.terraform_remote_state.compute.outputs.loadbalancer_fqdn},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes"

  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_cluster" {
  depends_on = [null_resource.kube_apiserver]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${data.terraform_remote_state.compute.outputs.loadbalancer_fqdn}:6443 --kubeconfig=${data.terraform_remote_state.compute.outputs.worker_name[count.index]}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_creds" {
  depends_on = [null_resource.kube_config_cluster]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config set-credentials system:node:${data.terraform_remote_state.compute.outputs.worker_name[count.index]} --client-certificate=${data.terraform_remote_state.compute.outputs.worker_name[count.index]}.pem --client-key=${data.terraform_remote_state.compute.outputs.worker_name[count.index]}-key.pem --embed-certs=true --kubeconfig=${data.terraform_remote_state.compute.outputs.worker_name[count.index]}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_context" {
  depends_on = [null_resource.kube_config_creds]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:${data.terraform_remote_state.compute.outputs.worker_name[count.index]} --kubeconfig=${data.terraform_remote_state.compute.outputs.worker_name[count.index]}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kubelet-kubernetes-configuration-file
resource "null_resource" "kube_config_default" {
  depends_on = [null_resource.kube_config_context]
  count      = 3
  provisioner "local-exec" {
    command = "kubectl config use-context default --cluster=kubernetes-the-hard-way --kubeconfig=${data.terraform_remote_state.compute.outputs.worker_name[count.index]}.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kube-proxy-kubernetes-configuration-file

resource "null_resource" "kube_proxy_cluster" {
  depends_on = [null_resource.kube_config_default]
  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${data.terraform_remote_state.compute.outputs.loadbalancer_fqdn}:6443 --kubeconfig=kube-proxy.kubeconfig"
  }
}

resource "null_resource" "kube_proxy_creds" {
  depends_on = [null_resource.kube_proxy_cluster]
  provisioner "local-exec" {
    command = "kubectl config set-credentials system:kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig"
  }
}

resource "null_resource" "kube_proxy_context" {
  depends_on = [null_resource.kube_proxy_creds]
  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-proxy --kubeconfig=kube-proxy.kubeconfig"
  }
}

resource "null_resource" "kube_proxy_default" {
  depends_on = [null_resource.kube_proxy_context]
  provisioner "local-exec" {
    command = "kubectl config use-context default --cluster=kubernetes-the-hard-way --kubeconfig=kube-proxy.kubeconfig"
  }
}

resource "null_resource" "kube_controller_cluster" {
  depends_on = [null_resource.kube_proxy_default]
  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=kube-controller-manager.kubeconfig"
  }
}

resource "null_resource" "kube_controller_creds" {
  depends_on = [null_resource.kube_controller_cluster]
  provisioner "local-exec" {
    command = "kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager.pem --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig"
  }
}

resource "null_resource" "kube_controller_context" {
  depends_on = [null_resource.kube_controller_creds]
  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig"
  }
}


resource "null_resource" "kube_controller_default" {
  depends_on = [null_resource.kube_controller_context]
  provisioner "local-exec" {
    command = "kubectl config use-context default --cluster=kubernetes-the-hard-way --kubeconfig=kube-controller-manager.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-kube-scheduler-kubernetes-configuration-file
resource "null_resource" "kube_scheduler_cluster" {
  depends_on = [null_resource.kube_controller_default]
  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=kube-scheduler.kubeconfig"
  }
}

resource "null_resource" "kube_scheduler_creds" {
  depends_on = [null_resource.kube_scheduler_cluster]
  provisioner "local-exec" {
    command = "kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=kube-scheduler.kubeconfig"
  }
}

resource "null_resource" "kube_scheduler_context" {
  depends_on = [null_resource.kube_scheduler_creds]
  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig"
  }
}

resource "null_resource" "kube_scheduler_default" {
  depends_on = [null_resource.kube_scheduler_context]
  provisioner "local-exec" {
    command = "kubectl config use-context default --cluster=kubernetes-the-hard-way --kubeconfig=kube-scheduler.kubeconfig"
  }
}

# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md#the-admin-kubernetes-configuration-file
resource "null_resource" "admin_cluster" {
  depends_on = [null_resource.kube_scheduler_default]
  provisioner "local-exec" {
    command = "kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=admin.kubeconfig"
  }
}

resource "null_resource" "admin_creds" {
  depends_on = [null_resource.admin_cluster]
  provisioner "local-exec" {
    command = "kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=admin.kubeconfig"
  }
}

resource "null_resource" "admin_context" {
  depends_on = [null_resource.admin_creds]
  provisioner "local-exec" {
    command = "kubectl config set-context default --cluster=kubernetes-the-hard-way --user=admin --kubeconfig=admin.kubeconfig"
  }
}

resource "null_resource" "admin_default" {
  depends_on = [null_resource.admin_context]
  provisioner "local-exec" {
    command = "kubectl config use-context default --cluster=kubernetes-the-hard-way --kubeconfig=admin.kubeconfig"
  }
}

resource "random_string" "encryption_base" {
  length  = 32
  special = false
}

resource "local_file" "encryption_config" {
  depends_on = [random_string.encryption_base]
  content    = <<-EOT
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${base64encode(random_string.encryption_base.result)}
      - identity: {}
  EOT

  filename = "./encryption-config.yaml"
}