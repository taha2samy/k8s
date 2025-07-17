#!/bin/bash
set -euxo pipefail
NODE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/instance-id | cut -d. -f1)
hostnamectl set-hostname $NODE_NAME
exec > >(tee /var/log/cloud-init-kubernetes.log) 2>&1

${common_prereqs_script}

if [ ! -f "/etc/kubernetes/pki/ca.crt" ]; then
    printf "%s" "${kubeadm_join_command}" | sudo bash
else
    echo "Node already appears to be joined (ca.crt exists)."
fi

mkdir -p "/home/${ansible_user}/.kube"
echo "${kubeconfig_content}" | sudo tee "/home/${ansible_user}/.kube/config" >/dev/null
sudo chmod 600 "/home/${ansible_user}/.kube/config"
sudo chown -R ${ansible_user}:${ansible_user} "/home/${ansible_user}/.kube"


export KUBECONFIG="/home/${ansible_user}/.kube/config"

sudo -u ${ansible_user} kubectl label node "$NODE_NAME" node-role.kubernetes.io/worker= --overwrite=true
