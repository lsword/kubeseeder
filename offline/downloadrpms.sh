#!/bin/bash

yum clean all
yum makecache

yum install -y deltarpm yum-utils epel-release
yum install -y wget
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum clean all
yum makecache

mkdir -p /createrepo
mkdir -p /rpms

cd /createrepo
repotrack createrepo
rm -rf *i686*

cd /rpms
#repotrack docker-ce kubelet-$K8S_VERSION-0 kubectl-$K8S_VERSION-0  kubeadm-$K8S_VERSION-0
repotrack docker-ce
repotrack socat conntrack cri-tools ebtables kubernetes-cni
repotrack nfs-utils
repotrack chrony ipvsadm ipset bridge-utils net-tools lrzsz vim wget curl
#yumdownloader --resolve kubelet-$K8S_VERSION-0 kubectl-$K8S_VERSION-0  kubeadm-$K8S_VERSION-0
rm -rf *i686*

