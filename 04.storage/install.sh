#!/bin/bash

NFS_SERVER=$(yq '.storage.nfs.server' ../config.yaml)
NFS_PATH=$(yq '.storage.nfs.path' ../config.yaml)
TMP_NFS_PATH=`echo $NFS_PATH | sed 's#\/#\\\/#g'`

sed "s/NFS_SERVER/$NFS_SERVER/g" nfs-subdir-external-provisioner.yaml.template | sed "s/NFS_PATH/$TMP_NFS_PATH/g" > nfs-subdir-external-provisioner.yaml

helm install nfs-provisioner nfs-subdir-external-provisioner -n kube-system -f nfs-subdir-external-provisioner.yaml
