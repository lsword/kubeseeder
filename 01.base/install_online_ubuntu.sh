#!/bin/bash

#==================================================================================================================
# Load config
#------------------------------------------------------------------------------------------------------------------
K8S_DOMAIN=$(yq '.k8s.domain' ../config.yaml)
K8S_VERSION=$(yq '.k8s.version' ../config.yaml)

#==================================================================================================================
# Install apt source
#------------------------------------------------------------------------------------------------------------------
apt-get update && apt-get install -y apt-transport-https gnupg curl

#==================================================================================================================
# Install chrony
#------------------------------------------------------------------------------------------------------------------
apt-get install -y chrony
systemctl start chronyd
systemctl enable chronyd

#==================================================================================================================
# Install nfs-utils
#------------------------------------------------------------------------------------------------------------------
yum install -y nfs-kernel-server nfs-common

#==================================================================================================================
# Install docker
#------------------------------------------------------------------------------------------------------------------
apt-get install -y ca-certificates     curl     gnupg     lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io

mkdir -p /etc/docker

cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "insecure-registries" : ["core.harbor.$K8S_DOMAIN"]
}
EOF

tee  /etc/sysctl.d/docker.conf <<EOF
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
EOF

sysctl --system

systemctl daemon-reload
systemctl restart docker
systemctl enable docker

#==================================================================================================================
# Install k8s 
#------------------------------------------------------------------------------------------------------------------
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
cat << EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubectl=$K8S_VERSION-00 kubelet=$K8S_VERSION-00 kubeadm=$K8S_VERSION-00

systemctl enable kubelet
systemctl restart kubelet
