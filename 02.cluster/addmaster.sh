#!/bin/bash

K8S_CLUSTER_DOMAIN=cluster.$(yq '.k8s.domain' ../config.yaml)
K8S_CLUSTER_IP=$(yq '.k8s.clusterIP' ../config.yaml)

# check hostname
HOSTNAME=$(hostname)
if [ $HOSTNAME == "localhost" ]; then
  echo "Hostname is localhost, Please change hostname by hostname-ctl."
  exit 1
fi

# set /etc/hosts
echo "127.0.0.1 $(hostname)" >> /etc/hosts
echo "$K8S_CLUSTER_IP $K8S_CLUSTER_DOMAIN" >> /etc/hosts

echo "Exec 'kubeadm token create --print-join-command' on first master node, and follow the instruction to add this machine as a k8s master."
