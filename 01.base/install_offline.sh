#!/bin/bash

OS_RELEASE=$(yq '.os.release' ../config.yaml)
OS_VERSION=$(yq '.os.version' ../config.yaml)
K8S_VERSION=$(yq '.k8s.version' ../config.yaml)
K8S_DOMAIN=$(yq '.k8s.domain' ../config.yaml)

#==================================================================================================================
# Install pkgs
#------------------------------------------------------------------------------------------------------------------
if [ $OS_RELEASE == "centos" ]; then
  # Install createrepo
  rpm -ivh --replacefiles --replacepkgs ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/createrepo/*.rpm

  # Create local repo
  mkdir -p /mnt/packages
  cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/rpms/* /mnt/packages
  createrepo /mnt/packages
  mkdir /etc/yum.repo.bak
  mv /etc/yum.repos.d/* /etc/yum.repo.bak

  cat <<EOF > /etc/yum.repos.d/local.repo
[local]
name=local.repo
baseurl=file:///mnt/packages
enabled=1
gpgcheck=0
EOF

  yum clean all
  yum makecache

  # Install software
  yum install -y docker-ce
  yum install -y socat conntrack cri-tools ebtables kubernetes-cni
  yum install -y nfs-utils
  yum install -y chrony ipvsadm bridge-utils net-tools lrzsz vim wget curl

elif [ $OS_RELEASE == "ubuntu" ]; then
  # Create local repo
  mv ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/debs /
  mv /etc/apt/sources.list /etc
  echo "deb file:/debs ./"  > /etc/apt/sources.list
  apt-get update --allow-insecure-repositories

  # Install software
  export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
  apt-get install -y docker-ce --allow-unauthenticated
  apt-get install -y socat conntrack cri-tools ebtables kubernetes-cni --allow-unauthenticated
  apt-get install -y nfs-kernel-server nfs-common --allow-unauthenticated
  apt-get install -y chrony ipvsadm bridge-utils net-tools lrzsz vim wget curl --allow-unauthenticated

else
  echo "Does not support for $OS_RELEASE"
  exit 1
fi

#==================================================================================================================
# Config timezone 
#------------------------------------------------------------------------------------------------------------------
timedatectl set-timezone Asia/Shanghai

#==================================================================================================================
# Config docker
#------------------------------------------------------------------------------------------------------------------
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

#==================================================================================================================
# Start docker
#------------------------------------------------------------------------------------------------------------------
systemctl restart docker
systemctl enable docker

#==================================================================================================================
# Prepare k8s
#------------------------------------------------------------------------------------------------------------------
systemctl stop kubelet
cd ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/
tar xfvz kubernetes-node-linux-amd64.tar.gz
cd -
alias cp=cp
cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes/node/bin/kubectl /usr/bin
cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes/node/bin/kubelet /usr/bin
cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes/node/bin/kubeadm /usr/bin
alias cp='cp -i'

#==================================================================================================================
# Config kubelet
#------------------------------------------------------------------------------------------------------------------
cat <<EOF > /usr/lib/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target

EOF

mkdir -p /usr/lib/systemd/system/kubelet.service.d

cat <<EOF > /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS

EOF

#==================================================================================================================
# Start kubelet
#------------------------------------------------------------------------------------------------------------------
systemctl enable kubelet
systemctl restart kubelet

#==================================================================================================================
# Load images
#------------------------------------------------------------------------------------------------------------------
K8S_IMAGEDIR="../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/images"
../offline/loadimgs.sh $K8S_IMAGEDIR
SYSAPPS_IMAGEDIR="../offline/sysapps"
../offline/loadimgs.sh $SYSAPPS_IMAGEDIR
APPS_IMAGEDIR="../offline/apps/images"
../offline/loadimgs.sh $APPS_IMAGEDIR
