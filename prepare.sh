#!/bin/bash

wget -c https://github.com/mikefarah/yq/releases/download/v4.25.1/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq

K8S_VERSION=$(yq '.k8s.version' config.yaml)

#==================================================================================================================
# Network
#------------------------------------------------------------------------------------------------------------------
CALICO_VERSION=$(yq '.networkPlugin.calico.version' config.yaml)
wget -c https://projectcalico.docs.tigera.io/archive/v$CALICO_VERSION/manifests/calico.yaml -O ./03.network/calico.yaml --no-check-certificate

FLANNEL_VERSION=$(yq '.networkPlugin.flannel.version' config.yaml)
wget -c https://raw.githubusercontent.com/flannel-io/flannel/v$FLANNEL_VERSION/Documentation/kube-flannel.yml -O ./03.network/flannel.yaml --no-check-certificate

#==================================================================================================================
# Generate offline packages
#------------------------------------------------------------------------------------------------------------------
INSTALL_MODE=$(yq '.k8s.installMode' config.yaml)
echo $INSTALL_MODE
if [ $INSTALL_MODE == "online" ]; then
  exit 0
fi 
cd ./offline
  ./genoffline.sh
cd -

exit 0

#==================================================================================================================
# Tools
#------------------------------------------------------------------------------------------------------------------

# helm
HELM_VERSION=$(yq '.tools.helm.version' config.yaml)
wget -c https://get.helm.sh/helm-v$HELM_VERSION-linux-amd64.tar.gz -O ./tools/helm.tgz --no-check-certificate
cd ./tools
tar xfvz helm.tgz
mv linux-amd64/helm bin 
rm -rf helm.tgz linux-amd64
cd ..

# etcdctl
# calicoctl
# k9s

#==================================================================================================================
# Download app images
#------------------------------------------------------------------------------------------------------------------

APPS_DIR=offline/apps

# metric-server
echo "docker.io/bitnami/metrics-server:0.6.1" > $APPS_DIR/imgs

# ingress-nginx
echo "docker.io/lsword/ingress-nginx-controller:v1.1.3" >> $APPS_DIR/imgs

# dashboard
echo "docker.io/kubernetesui/dashboard:v2.5.1" >> $APPS_DIR/imgs
echo "docker.io/kubernetesui/metrics-scraper:v1.0.7" >> $APPS_DIR/imgs

# kube-prometheus

# harbor
echo "docker.io/goharbor/nginx-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/harbor-portal:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/harbor-core:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/harbor-jobservice:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/registry-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/harbor-registryctl:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/chartmuseum-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/trivy-adapter-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/notary-server-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/notary-signer-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/harbor-db:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/redis-photon:v2.4.2" >> $APPS_DIR/imgs
echo "docker.io/goharbor/harbor-exporter:v2.4.2" >> $APPS_DIR/imgs

# common
echo "docker.io/library/registry:latest" >> $APPS_DIR/imgs
echo "docker.io/library/centos:7" >> $APPS_DIR/imgs
echo "docker.io/library/busybox:stable" >> $APPS_DIR/imgs
echo "docker.io/library/busybox:stable-glibc" >> $APPS_DIR/imgs
echo "docker.io/library/alpine:3.15.4" >> $APPS_DIR/imgs
echo "docker.io/library/nginx:alpine" >> $APPS_DIR/imgs
echo "docker.io/library/nicolaka/netshoot:latest" >> $APPS_DIR/imgs

return 0

# save images to files
rm -rf $APPS_DIR/images
mkdir -p $APPS_DIR/images
cd $APPS_DIR
while read image
do
iar=(`echo $image | tr '/' ' '`)
echo $image
imagename=${iar[${#iar[@]}-1]}
echo $imagename
docker pull $image
docker save -o images/$imagename.tar $image
done < imgs
cd -
