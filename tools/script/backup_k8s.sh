#!/bin/bash

mkdir -p /root/.k8sbackup

mount -t nfs sfs-nas01.ap-southeast-1a.myhuaweicloud.com:/share-898a1d6d /root/.k8sbackup

cp -r /etc/kubernetes /root/.k8sbackup/k8s/backup/config/$(hostname)_etc_kubernetes.$(date "+%Y%m%d")
export ETCDCTL_API=3
etcdctl --key=/etc/kubernetes/pki/etcd/server.key --cert=/etc/kubernetes/pki/etcd/server.crt --cacert=/etc/kubernetes/pki/etcd/ca.crt --endpoints https://127.0.0.1:2379 snapshot save /root/.k8sbackup/k8s/backup/etcd/k8s_etcd_$(hostname)_$(date "+%Y%m%d").db

find /root/.k8sbackup/k8s/backup/etcd/ -mtime +3 -name "*.db" -exec rm -rf {} \;

umount /root/.k8sbackup