#!/bin/bash

K8S_SINGLE_NODE=$(yq '.k8s.singleNode' ../config.yaml)

NFS_SERVER=$(yq '.storage.nfs.server' ../config.yaml)
NFS_PATH=$(yq '.storage.nfs.path' ../config.yaml)
TMP_NFS_PATH=`echo $NFS_PATH | sed 's#\/#\\\/#g'`

if [ $K8S_SINGLE_NODE == 'true' ]; then
  helm install local-path-provisioner local-path-provisioner -f local-path-provisioner.yaml -n kube-system
else
  sed "s/NFS_SERVER/$NFS_SERVER/g" nfs-subdir-external-provisioner.yaml.template | sed "s/NFS_PATH/$TMP_NFS_PATH/g" > nfs-subdir-external-provisioner.yaml

  helm install nfs-provisioner nfs-subdir-external-provisioner -n kube-system -f nfs-subdir-external-provisioner.yaml
fi
