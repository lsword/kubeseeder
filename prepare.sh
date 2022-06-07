#!/bin/bash

wget -c https://github.com/mikefarah/yq/releases/download/v4.25.1/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
cp /usr/local/bin/yq tools/bin

K8S_VERSION=$(yq '.k8s.version' config.yaml)
K8S_INSTALLMODE=$(yq '.k8s.installMode' config.yaml)

#==================================================================================================================
# Network
#------------------------------------------------------------------------------------------------------------------
CALICO_VERSION=$(yq '.networkPlugin.calico.version' config.yaml)
wget -c https://projectcalico.docs.tigera.io/archive/v$CALICO_VERSION/manifests/calico.yaml -O ./03.network/calico.yaml --no-check-certificate
if [ $? -ne 0 ]; then
  echo "Can not down https://projectcalico.docs.tigera.io/archive/v$CALICO_VERSION/manifests/calico.yaml, please check your network or your config."
  exit 1
fi

FLANNEL_VERSION=$(yq '.networkPlugin.flannel.version' config.yaml)
wget -c https://raw.githubusercontent.com/flannel-io/flannel/v$FLANNEL_VERSION/Documentation/kube-flannel.yml -O ./03.network/flannel.yaml --no-check-certificate
if [ $? -ne 0 ]; then
  echo "Can not down https://raw.githubusercontent.com/flannel-io/flannel/v$FLANNEL_VERSION/Documentation/kube-flannel.yml, please check your network or your config."
  exit 1
fi

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
K9S_VERSION=$(yq '.tools.k9s.version' config.yaml)
wget -c https://github.com/derailed/k9s/releases/download/v$K9S_VERSION/k9s_Linux_x86_64.tar.gz -O ./tools/k9s.tgz --no-check-certificate
cd ./tools
mkdir k9s
tar xfvz k9s.tgz -C k9s
mv k9s/k9s bin
rm -rf k9s.tgz k9s
cd ..

if [ $K8S_INSTALLMODE == "online" ];then
  exit 0
fi

#==================================================================================================================
# Generate offline packages
#------------------------------------------------------------------------------------------------------------------
cd ./offline
  ./genoffline.sh
cd -

#==================================================================================================================
# Download app images
#------------------------------------------------------------------------------------------------------------------

APPS_DIR=offline/apps

# metric-server
METRIC_SERVER_ENABLED=$(yq '.apps.metrics-server.enabled' config.yaml)
METRIC_SERVER_VERSION=$(yq '.apps.metrics-server.version' config.yaml)
if [ $METRIC_SERVER_ENABLED == "true" ]; then
  echo "docker.io/bitnami/metrics-server:$METRIC_SERVER_VERSION" > $APPS_DIR/imgs
fi

# ingress-nginx
INGRESS_NGINX_ENABLED=$(yq '.apps.ingress-nginx.enabled' config.yaml)
INGRESS_NGINX_VERSION=$(yq '.apps.ingress-nginx.version' config.yaml)
if [ $INGRESS_NGINX_ENABLED == "true" ]; then
  echo "docker.io/lsword/ingress-nginx-controller:v$INGRESS_NGINX_VERSION" >> $APPS_DIR/imgs
fi

# dashboard
DASHBOARD_ENABLED=$(yq '.apps.dashboard.enabled' config.yaml)
DASHBOARD_VERSION=$(yq '.apps.dashboard.version' config.yaml)
if [ $DASHBOARD_ENABLED == "true" ]; then
  echo "docker.io/kubernetesui/dashboard:v$DASHBOARD_VERSION" >> $APPS_DIR/imgs
  echo "docker.io/kubernetesui/metrics-scraper:v1.0.7" >> $APPS_DIR/imgs
fi

# harbor
HARBOR_ENABLED=$(yq '.apps.harbor.enabled' config.yaml)
HARBOR_VERSION=$(yq '.apps.harbor.version' config.yaml)
if [ $HARBOR_ENABLED == "true" ]; then
  wget -c https://github.com/goharbor/harbor/releases/download/v$HARBOR_VERSION/harbor-offline-installer-v$HARBOR_VERSION.tgz -O $APPS_DIR/harbor-offline-installer-v$HARBOR_VERSION.tgz
fi

<<comment
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
comment

# kube-prometheus
KUBE_PROMETHEUS_ENABLED=$(yq '.apps.kube-prometheus.enabled' config.yaml)
if [ $KUBE_PROMETHEUS_ENABLED == "true" ]; then
  echo "to be add"
fi

# common
echo "docker.io/library/registry:latest" >> $APPS_DIR/imgs
echo "docker.io/library/centos:7" >> $APPS_DIR/imgs
echo "docker.io/library/busybox:stable" >> $APPS_DIR/imgs
echo "docker.io/library/busybox:stable-glibc" >> $APPS_DIR/imgs
echo "docker.io/library/alpine:latest" >> $APPS_DIR/imgs
echo "docker.io/library/nginx:alpine" >> $APPS_DIR/imgs
echo "docker.io/nicolaka/netshoot:latest" >> $APPS_DIR/imgs

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
gzip images/*.tar
cd -
