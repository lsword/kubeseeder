#!/bin/bash

kubeadm reset -f
systemctl stop kubelet
systemctl stop docker
rm -rf /etc/kubernetes/*
rm -rf /var/lib/kubelet/*
rm -rf $HOME/.kube
rm -rf /var/lib/cni/
rm -rf /etc/cni/
rm -rf /var/lib/calico
ip link set cni0 down
ip link set flannel.1 down
ip link set docker0 down
ip link delete cni0
ip link delete flannel.1
ip link delete kube-ipvs0
systemctl start docker

ipvsadm --clear
