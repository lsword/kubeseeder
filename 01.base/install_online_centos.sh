#!/bin/bash

#==================================================================================================================
# Load config
#------------------------------------------------------------------------------------------------------------------
K8S_DOMAIN=$(yq '.k8s.domain' ../config.yaml)
K8S_VERSION=$(yq '.k8s.version' ../config.yaml)

#==================================================================================================================
# Install base yum software
#------------------------------------------------------------------------------------------------------------------
yum install -y deltarpm yum-utils epel-release

#==================================================================================================================
# Install chrony
#------------------------------------------------------------------------------------------------------------------
yum install -y chrony
systemctl start chronyd
systemctl enable chronyd

#==================================================================================================================
# Install nfs-utils
#------------------------------------------------------------------------------------------------------------------
yum install -y nfs-utils

#==================================================================================================================
# Install docker
#------------------------------------------------------------------------------------------------------------------
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum makecache

yum install -y docker-ce --nogpgcheck

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
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum makecache

yum install -y kubeadm-$K8S_VERSION-0 kubelet-$K8S_VERSION-0 kubectl-$K8S_VERSION-0 --disableexcludes=kubernetes
systemctl enable kubelet
systemctl restart kubelet

kubeadm version

