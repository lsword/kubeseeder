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

