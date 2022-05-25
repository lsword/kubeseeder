#!/bin/bash

OS_RELEASE=$(yq '.os.release' ../config.yaml)
OS_VERSION=$(yq '.os.version' ../config.yaml)
K8S_VERSION=$(yq '.k8s.version' ../config.yaml)
K8S_INSTALLMODE=$(yq '.k8s.installMode' ../config.yaml)

Usage() {
  cat <<EOF
upgrade.sh <firstmaster|othermaster|node>
  firstmaster: upgrade first master
  othermaster: upgrade other master
  node:        upgrade node
EOF
  exit 1
}

if [ $# -ne 1 ] || ( [ $1 != "firstmaster" ] && [ $1 != "othermaster" ] && [ $1 != "node" ] );then
  Usage
fi

K8S_NODE=$1

#==================================================================================================================
# Install k8s
#------------------------------------------------------------------------------------------------------------------
if [ $K8S_INSTALLMODE == "online" ];then
  if [ $OS_RELEASE == "centos" ]; then
    yum makecache
    yum install -y kubeadm-$K8S_VERSION-0 kubelet-$K8S_VERSION-0 kubectl-$K8S_VERSION-0 --disableexcludes=kubernetes
  elif [ $OS_RELEASE == "ubuntu" ]; then
    apt-get update
    apt-get install -y kubectl=$K8S_VERSION-00 kubelet=$K8S_VERSION-00 kubeadm=$K8S_VERSION-00
  else
    echo "Does not support for $OS_RELEASE"
    exit 1
  fi
else
  # Install binary files
  systemctl stop kubelet
  cd ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/
  tar xfvz kubernetes-node-linux-amd64.tar.gz
  cd -
  alias cp=cp
  cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes/node/bin/kubectl /usr/bin
  cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes/node/bin/kubelet /usr/bin
  cp ../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes/node/bin/kubeadm /usr/bin
  alias cp='cp -i'

  # Load k8s images
  K8S_IMAGEDIR="../offline/$K8S_VERSION-$OS_RELEASE$OS_VERSION/images"
  ../offline/loadimgs.sh $K8S_IMAGEDIR
fi

#==================================================================================================================
# Upgrade k8s service
#------------------------------------------------------------------------------------------------------------------
if [ $K8S_NODE == "firstmaster" ]; then
  #kubectl drain `hostname` --force --ignore-daemonsets --delete-emptydir-data
  #ubeadm upgrade plan
  kubeadm upgrade apply v$K8S_VERSION -y
  kubectl uncordon `hostname`
elif [ $K8S_NODE == "othermaster" ]; then
  kubectl drain `hostname` --force --ignore-daemonsets --delete-emptydir-data
  kubeadm upgrade node -y
  kubectl uncordon `hostname`
elif [ $K8S_NODE == "node" ]; then
  kubectl drain `hostname` --force --ignore-daemonsets --delete-emptydir-data
  kubeadm upgrade node -y
  kubectl uncordon `hostname`
fi

#==================================================================================================================
# Restart k8s service
#------------------------------------------------------------------------------------------------------------------
systemctl daemon-reload
systemctl restart kubelet
