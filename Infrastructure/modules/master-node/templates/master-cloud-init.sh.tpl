#!/bin/bash
sudo apt update
sudo apt install -y nfs-common
sudo apt install docker.io -y
sudo apt install awscli -y
ECR_REGISTRY_URL=${ECR_REGISTRY_URL}
ECR_REGION=${ECR_REGION}
ECR_REPO_NAME="nginx"
sudo usermod -aG docker ${ansible_user}
echo 'export ECR_REGISTRY_URL=${ECR_REGISTRY_URL}' >> /home/ubuntu/.bashrc
echo 'export ECR_REGION=${ECR_REGION}' >> /home/ubuntu/.bashrc
echo 'export ECR_REPO_NAME="nginx"' >> /home/ubuntu/.bashrc
source /home/ubuntu/.bashrc
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm -y
sudo apt-get nfs-kernel-server -y
# sudo docker pull nginx:latest
# sudo docker tag nginx:latest "$ECR_REGISTRY_URL"
# sudo aws ecr get-login-password --region "$ECR_REGION"
# aws ecr get-login-password --region "$ECR_REGION" | \
# docker login --username AWS --password-stdin \
# "${ECR_REGISTRY_URL}"
# docker tag nginx:latest "$ECR_REGISTRY_URL"
# docker push "$ECR_REGISTRY_URL"

# Common Kubernetes prerequisites script
set -euxo pipefail
apt update && apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  nfs-common

# Redirect all output to a log file for debugging
exec > >(tee /var/log/cloud-init-kubernetes.log) 2>&1

echo "Starting common Kubernetes prerequisites setup..."

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules and configure sysctl for Kubernetes
echo "Configuring kernel modules and sysctl parameters..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Install containerd and runc
echo "Installing containerd and runc..."

# Install necessary packages for apt transport and GPG
apt update
apt install -y apt-transport-https ca-certificates curl gpg

# Install containerd using the official release tarball (mimicking Ansible)
CONTAINERD_VERSION="2.0.3"
CONTAINERD_TGZ="containerd-$CONTAINERD_VERSION-linux-amd64.tar.gz"
CONTAINERD_URL="https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERSION/$CONTAINERD_TGZ"

if [ ! -f "/usr/local/bin/containerd" ]; then
    echo "Downloading and installing containerd..."
    curl -L "$CONTAINERD_URL" -o "/tmp/$CONTAINERD_TGZ"
    tar Cxzvf /usr/local "/tmp/$CONTAINERD_TGZ"
    mkdir -p /usr/local/lib/systemd/system

    # Download containerd systemd service file
    curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /usr/local/lib/systemd/system/containerd.service
else
    echo "Containerd already installed."
fi

# Install runc
RUNC_VERSION="1.2.5"
RUNC_BIN="runc.amd64"
RUNC_URL="https://github.com/opencontainers/runc/releases/download/v$RUNC_VERSION/$RUNC_BIN"

if [ ! -f "/usr/local/sbin/runc" ]; then
    echo "Downloading and installing runc..."
    curl -L "$RUNC_URL" -o "/tmp/$RUNC_BIN"
    install -m 755 "/tmp/$RUNC_BIN" /usr/local/sbin/runc
else
    echo "Runc already installed."
fi

# Install CNI plugins
CNI_VERSION="v1.6.2"
CNI_TGZ="cni-plugins-linux-amd64-$CNI_VERSION.tgz"
CNI_URL="https://github.com/containernetworking/plugins/releases/download/$CNI_VERSION/$CNI_TGZ"

if [ ! -d "/opt/cni/bin" ]; then
    echo "Downloading and installing CNI plugins..."
    mkdir -p /opt/cni/bin
    curl -L "$CNI_URL" -o "/tmp/$CNI_TGZ"
    tar Cxzvf /opt/cni/bin "/tmp/$CNI_TGZ"
else
    echo "CNI plugins already installed."
fi

# Configure containerd for systemd cgroup driver
echo "Configuring containerd..."
mkdir -p /etc/containerd
if ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
    containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
fi

echo "Enabling and starting containerd service..."
systemctl daemon-reload
systemctl enable containerd --now
systemctl restart containerd

echo "Verifying containerd status..."
ctr --address /var/run/containerd/containerd.sock info || true # Ignore error if it's not fully up yet

# Add Kubernetes apt repository
echo "Adding Kubernetes apt repository..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # Ensure correct permissions
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, kubectl
echo "Installing kubeadm, kubelet, and kubectl..."
apt update
apt install -y kubeadm kubelet kubectl

# Enable and start kubelet service
echo "Enabling and starting kubelet service..."
systemctl enable kubelet --now
systemctl restart kubelet

echo "Common Kubernetes prerequisites setup completed." 

echo "Starting Kubernetes master node setup..."

# Set hostname
hostnamectl set-hostname controlplane

# hi Check if Kubernetes is already initialized
if [ ! -f "/etc/kubernetes/admin.conf" ]; then
    echo "Initializing Kubernetes cluster with kubeadm..."
    # --pod-network-cidr should match your CNI plugin's requirement (Calico uses 10.244.0.0/16 by default)
    export PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    export PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    kubeadm init \
      --control-plane-endpoint="$PUBLIC_IP:6443" \
      --apiserver-cert-extra-sans="$PRIVATE_IP" \
      --upload-certs

    echo "Configuring kubectl for ${ansible_user} user..."
    mkdir -p "/home/${ansible_user}/.kube"
    # IMPORTANT FIX: Copy admin.conf AND set correct ownership/permissions for the ubuntu user
    # This ensures `kubectl` works without `sudo` for the ubuntu user
    sudo cp /etc/kubernetes/admin.conf "/home/${ansible_user}/.kube/config"
    sudo chown -R ${ansible_user}:${ansible_user} "/home/${ansible_user}/.kube"
    sudo chmod 0600 "/home/${ansible_user}/.kube/config" # Make it readable only by owner for security

    echo "Applying Calico CNI network plugin..."
    kubectl --kubeconfig=/home/${ansible_user}/.kube/config apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

else
    echo "Kubernetes cluster appears to be already initialized (admin.conf exists)."
fi


if ! sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get priorityclass system-node-critical >/dev/null 2>&1; then
    echo "Creating system-node-critical and system-cluster-critical PriorityClasses..."
    cat <<EOF | sudo tee /etc/kubernetes/manifests/priority-classes.yaml
    ${priority_classes_yaml}
EOF
    sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /etc/kubernetes/manifests/priority-classes.yaml
fi

echo "Deploying NFS CSI driver and StorageClass..."



 

helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system --create-namespace \
  --kubeconfig="/home/${ansible_user}/.kube/config"




cat <<EOF | sudo tee /tmp/nfs-csi-deploy.yaml

# ${nfs_namespace_yaml}
# ---
# ${nfs_csidriver_yaml}
# ---
${nfs_deployment_yaml}
# ---
# ${nfs_storageclass_yaml}
EOF

sudo kubectl --kubeconfig=/home/${ansible_user}/.kube/config apply -f /tmp/nfs-csi-deploy.yaml



echo "NFS CSI driver and StorageClass deployed."

CLUSTER_NAME="${cluster_name}"

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep '"region"' | awk -F'"' '{print $4}')

MAC=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/mac)
VPC_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/vpc-id)
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name="aws-load-balancer-controller" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --kubeconfig="/home/${ansible_user}/.kube/config"

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo "$AZ" | rev | cut -c 2- | rev)

sudo kubectl --kubeconfig="/home/ubuntu/.kube/config" patch node "controlplane" -p "{\"spec\":{\"providerID\":\"aws:///$AZ/$INSTANCE_ID\"}}"
