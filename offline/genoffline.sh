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
yum remove -y kubeadm kubelet kubectl
yum install -y kubeadm-$K8S_VERSION-0
  # need add check for kubeadm
kubeadm config images list --kubernetes-version v$K8S_VERSION | grep k8s.gcr.io | sed 's/k8s.gcr.io/registry.cn-hangzhou.aliyuncs.com\/google_containers/g' > $IMAGES_DIR/imgs
if [ $? -ne 0 ]; then
  echo "Get k8s image list error."
  exit 1
fi

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

