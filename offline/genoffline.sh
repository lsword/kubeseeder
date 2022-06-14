#!/bin/bash

#wget -c https://github.com/mikefarah/yq/releases/download/v4.25.1/yq_linux_amd64 -O /usr/local/bin/yq
#chmod +x /usr/local/bin/yq

OS_RELEASE=$(yq '.os.release' ../config.yaml)
OS_VERSION=$(yq '.os.version' ../config.yaml)
K8S_VERSION=$(yq '.k8s.version' ../config.yaml)

#==================================================================================================================
# Add repo
#------------------------------------------------------------------------------------------------------------------

<<comment
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
comment

#==================================================================================================================
# Clean dir
#------------------------------------------------------------------------------------------------------------------
rm -rf $K8S_VERSION-$OS_RELEASE$OS_VERSION
mkdir -p $K8S_VERSION-$OS_RELEASE$OS_VERSION

#==================================================================================================================
# Download rpms or debs for k8s
#------------------------------------------------------------------------------------------------------------------

docker pull $OS_RELEASE:$OS_VERSION
if [ $? -ne 0 ];then
  echo "Can not get docker image($OS_RELEASE:$OS_VERSION), please check os.release and os.version in your config.yaml."
  exit 1
fi
CONTAINER_NAME=$K8S_VERSION-$OS_RELEASE$OS_VERSION
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME

if [ $OS_RELEASE == "centos" ]; then
  CREATEREPO_DIR=$K8S_VERSION-$OS_RELEASE$OS_VERSION/createrepo
  mkdir -p $CREATEREPO_DIR
  RPMS_DIR=$K8S_VERSION-$OS_RELEASE$OS_VERSION/rpms
  mkdir -p $RPMS_DIR
  docker run -d --name $CONTAINER_NAME \
             -e K8S_VERSION=$K8S_VERSION \
             -v $PWD/$RPMS_DIR:/rpms \
             -v $PWD/$CREATEREPO_DIR:/createrepo \
             -v $PWD/downloadrpms.sh:/downloadrpms.sh \
             $OS_RELEASE:$OS_VERSION \
             /downloadrpms.sh
  docker logs -f $CONTAINER_NAME
  docker rm $CONTAINER_NAME
elif [ $OS_RELEASE == "ubuntu" ]; then
  DEBS_DIR=/tmp/$K8S_VERSION-$OS_RELEASE$OS_VERSION/debs
  mkdir -p $DEBS_DIR
  chmod -R 777 /tmp/$K8S_VERSION-$OS_RELEASE$OS_VERSION
  docker run -d --name $CONTAINER_NAME \
             -e K8S_VERSION=$K8S_VERSION \
             -v $DEBS_DIR:/debs \
             -v $PWD/downloaddebs.sh:/downloaddebs.sh \
             $OS_RELEASE:$OS_VERSION \
             /downloaddebs.sh
  docker logs -f $CONTAINER_NAME
  docker rm $CONTAINER_NAME

  rm -rf $K8S_VERSION-$OS_RELEASE$OS_VERSION/debs
  mv /tmp/$K8S_VERSION-$OS_RELEASE$OS_VERSION/debs $K8S_VERSION-$OS_RELEASE$OS_VERSION
else
  echo "Does not support for $OS_RELEASE"
  exit 1
fi

#==================================================================================================================
# Download k8s binary files
#------------------------------------------------------------------------------------------------------------------
wget -c https://dl.k8s.io/v$K8S_VERSION/kubernetes-node-linux-amd64.tar.gz -O $K8S_VERSION-$OS_RELEASE$OS_VERSION/kubernetes-node-linux-amd64.tar.gz
if [ $? -ne 0 ]; then
  echo "Download k8s binnary files error."
  exit 1
fi

#==================================================================================================================
# Download k8s images
#------------------------------------------------------------------------------------------------------------------
IMAGES_DIR=$K8S_VERSION-$OS_RELEASE$OS_VERSION/images
mkdir -p $IMAGES_DIR
cd $K8S_VERSION-$OS_RELEASE$OS_VERSION/
tar xfvz kubernetes-node-linux-amd64.tar.gz
./kubernetes/node/bin/kubeadm config images list --kubernetes-version v$K8S_VERSION | grep k8s.gcr.io | sed 's/k8s.gcr.io/registry.cn-hangzhou.aliyuncs.com\/google_containers/g' > images/imgs
if [ $? -ne 0 ]; then
  echo "Get k8s image list error."
  exit 1
fi
rm -rf ./kubernetes
cd -

<<comment
yum remove -y kubeadm kubelet kubectl
yum install -y kubeadm-$K8S_VERSION-0
  # need add check for kubeadm
kubeadm config images list --kubernetes-version v$K8S_VERSION | grep k8s.gcr.io | sed 's/k8s.gcr.io/registry.cn-hangzhou.aliyuncs.com\/google_containers/g' > $IMAGES_DIR/imgs
comment

sed -i 's/\/coredns\//\//' $IMAGES_DIR/imgs

cd $IMAGES_DIR
while read image
do
iar=(`echo $image | tr '/' ' '`)
echo $image
imagename=${iar[${#iar[@]}-1]}
echo $imagename
docker pull $image
docker save -o $imagename.tar $image
done < imgs
gzip *.tar
cd -

#==================================================================================================================
# Network Plugin
#------------------------------------------------------------------------------------------------------------------
<<comment
CALICO_VERSION=$(yq '.networkPlugin.calico.version' ../config.yaml)
wget -c https://projectcalico.docs.tigera.io/archive/v$CALICO_VERSION/manifests/calico.yaml -O ../03.network/calico.yaml --no-check-certificate

FLANNEL_VERSION=$(yq '.networkPlugin.flannel.version' ../config.yaml)
wget -c https://raw.githubusercontent.com/flannel-io/flannel/v$FLANNEL_VERSION/Documentation/kube-flannel.yml -O ../03.network/flannel.yaml --no-check-certificate

comment

#==================================================================================================================
# Download SYSAPPS images
#------------------------------------------------------------------------------------------------------------------

INCLUDE_SYS_APPS=$(yq '.offline.includeSysApps' ../config.yaml)
if [ $INCLUDE_SYS_APPS == "true" ]; then
  SYSAPPS_DIR=sysapps
  mkdir -p $SYSAPPS_DIR
  rm -rf $SYSAPPS_DIR/imgs

  # calico
  grep "image:" ../03.network/calico.yaml | awk '{print $2}' >> $SYSAPPS_DIR/imgs

  # flannel
  grep "image:" ../03.network/flannel.yaml | grep -v "#image" | awk '{print $2}' >> $SYSAPPS_DIR/imgs

  # multus
  echo "ghcr.io/k8snetworkplumbingwg/multus-cni:thick" >> $SYSAPPS_DIR/imgs

  # nfs provisioner
  echo "docker.io/lsword/nfs-subdir-external-provisioner:v4.0.2" >> $SYSAPPS_DIR/imgs

  # local path provisioner
  echo "docker.io/rancher/local-path-provisioner:v0.0.22" >> $SYSAPPS_DIR/imgs
  echo "docker.io/busybox:latest" >> $SYSAPPS_DIR/imgs

  # save images
  cd $SYSAPPS_DIR
  rm -rf $SYSAPPS_DIR/*.gz $SYSAPPS_DIR/*.tar
  while read image
  do
    iar=(`echo $image | tr '/' ' '`)
    echo $image
    imagename=${iar[${#iar[@]}-1]}
    echo $imagename
    docker pull $image
    docker save -o $imagename.tar $image
    done < imgs
  gzip *.tar
  cd -

fi

#==================================================================================================================
# Download app images
#------------------------------------------------------------------------------------------------------------------

INCLUDE_APPS=$(yq '.offline.includeApps' ../config.yaml)
if [ $INCLUDE_APPS == "true" ]; then
  APPS_DIR=apps
  mkdir -p $APPS_DIR
  rm -rf $APPS_DIR/imgs

  # metric-server
  METRIC_SERVER_ENABLED=$(yq '.apps.metrics-server.enabled' ../config.yaml)
  METRIC_SERVER_VERSION=$(yq '.apps.metrics-server.version' ../config.yaml)
  if [ $METRIC_SERVER_ENABLED == "true" ]; then
    echo "docker.io/bitnami/metrics-server:$METRIC_SERVER_VERSION" > $APPS_DIR/imgs
  fi

  # ingress-nginx
  INGRESS_NGINX_ENABLED=$(yq '.apps.ingress-nginx.enabled' ../config.yaml)
  INGRESS_NGINX_VERSION=$(yq '.apps.ingress-nginx.version' ../config.yaml)
  if [ $INGRESS_NGINX_ENABLED == "true" ]; then
    echo "docker.io/lsword/ingress-nginx-controller:v$INGRESS_NGINX_VERSION" >> $APPS_DIR/imgs
  fi

  # dashboard
  DASHBOARD_ENABLED=$(yq '.apps.dashboard.enabled' ../config.yaml)
  DASHBOARD_VERSION=$(yq '.apps.dashboard.version' ../config.yaml)
  if [ $DASHBOARD_ENABLED == "true" ]; then
    echo "docker.io/kubernetesui/dashboard:v$DASHBOARD_VERSION" >> $APPS_DIR/imgs
    echo "docker.io/kubernetesui/metrics-scraper:v1.0.7" >> $APPS_DIR/imgs
  fi

  # harbor
  HARBOR_ENABLED=$(yq '.apps.harbor.enabled' ../config.yaml)
  HARBOR_VERSION=$(yq '.apps.harbor.version' ../config.yaml)
  if [ $HARBOR_ENABLED == "true" ]; then
    wget -c https://github.com/goharbor/harbor/releases/download/v$HARBOR_VERSION/harbor-offline-installer-v$HARBOR_VERSION.tgz -O $APPS_DIR/harbor-offline-installer-v$HARBOR_VERSION.tgz
  fi

  # kube-prometheus
  KUBE_PROMETHEUS_ENABLED=$(yq '.apps.kube-prometheus.enabled' ../config.yaml)
  if [ $KUBE_PROMETHEUS_ENABLED == "true" ]; then
    echo "quay.io/prometheus/alertmanager:v0.24.0" >> $APPS_DIR/imgs
    #echo "k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.1.1" >> $APPS_DIR/imgs
    echo "docker.io/liangjw/kube-webhook-certgen:v1.1.1" >> $APPS_DIR/imgs
    echo "quay.io/prometheus-operator/prometheus-operator:v0.56.3" >> $APPS_DIR/imgs
    echo "quay.io/prometheus-operator/prometheus-config-reloader:v0.56.3" >> $APPS_DIR/imgs
    echo "quay.io/thanos/thanos:v0.25.2" >> $APPS_DIR/imgs
    echo "quay.io/prometheus/prometheus:v2.35.0" >> $APPS_DIR/imgs
    echo "quay.io/prometheus/node-exporter:v1.3.1" >> $APPS_DIR/imgs
    echo "docker.io/grafana/grafana:8.5.5" >> $APPS_DIR/imgs
    echo "quay.io/kiwigrid/k8s-sidecar:1.15.6" >> $APPS_DIR/imgs
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

fi
