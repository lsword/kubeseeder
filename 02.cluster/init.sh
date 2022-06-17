#!/bin/bash

# load config
OS_RELEASE=$(yq '.os.release' ../config.yaml)
K8S_VERSION=$(yq '.k8s.version' ../config.yaml)
K8S_CLUSTER_DOMAIN=cluster.$(yq '.k8s.domain' ../config.yaml)
K8S_CLUSTER_IP=$(yq '.k8s.clusterIP' ../config.yaml)
K8S_SINGLE_NODE=$(yq '.k8s.singleNode' ../config.yaml)

# generate kubeadm.yaml
sed "s/K8S_VERSION/$K8S_VERSION/g" kubeadm.yaml.template | sed "s/K8S_CLUSTER_DOMAIN/$K8S_CLUSTER_DOMAIN/g" > kubeadm.yaml

# check hostname
HOSTNAME=$(hostname -s)
if [ $HOSTNAME == "localhost" ]; then
  echo "Hostname is localhost, Please change hostname by hostnamectl."
  exit 0
fi

# set /etc/hosts
echo "$(hostname -I | awk '{print $1}') $(hostname)" >> /etc/hosts
echo "$K8S_CLUSTER_IP $K8S_CLUSTER_DOMAIN" >> /etc/hosts

# 在master节点上启动集群
#kubeadm init --config ./kubeadmin_init.yaml | tee ./kube_init.log
kubeadm init --config ./kubeadm.yaml | tee ./kube_init.log

rm -rf $HOME/.kube
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 处理单节点模式
if [ $K8S_SINGLE_NODE == 'true' ]; then
  # 去除master的污点
  kubectl taint node $HOSTNAME node-role.kubernetes.io/master-
  # 加上针对ingress-nginx的标签
  kubectl label node $HOSTNAME kubernetes.io/hostlabel=ingress-nginx

  # 启动nfs
<<comment
  NFS_SERVER=$(yq '.storage.nfs.server' ../config.yaml)
  NFS_PATH=$(yq '.storage.nfs.path' ../config.yaml)
  NFS_IPRANGE=`echo $K8S_CLUSTER_IP | awk -F. '{print $1 "." $2 ".0.0/16"}'`
  mkdir -p $NFS_PATH
  echo "$NFS_PATH $NFS_IPRANGE(no_root_squash,rw,sync,fsid=0)" > /etc/exports
  if [ $OS_RELEASE == "centos" ]; then
    systemctl restart nfs
  elif [ $OS_RELEASE == "ubuntu" ]; then
    systemctl restart nfs-kernel-server
  fi
  echo "$K8S_CLUSTER_IP $NFS_SERVER" >> /etc/hosts
comment
fi

# 配置定时任务
cp ../tools/script/clean_k8spod.sh /usr/local/bin
cp ../tools/script/clean_docker.sh /usr/local/bin

cat <<EOF > /var/spool/cron/root
0 0 * * * /usr/local/bin/clean_docker.sh
0 0 1 * * /usr/local/bin/clean_k8spod.sh
EOF

# 配置alias
cat <<EOF >> ~/.bashrc

alias k=kubectl

alias kar='k api-resources'

alias kg='k get'
alias kgn='kg nodes'
alias kgd='kg deploy'
alias kgp='kg pods'
alias kgs='kg svc'
alias kge='kg events'
alias kgds='kg daemonset'
alias kgss='kg sts'
alias kgj='kg job'
alias kgcj='kg cronjob'
alias kgcrd='kg crd'

alias kd='k describe'
alias kdn='kd nodes'
alias kdd='kd deploy'
alias kdp='kd pods'
alias kds='kd svc'
alias kdds='kd daemonset'
alias kdss='kd sts'
alias kdj='kd job'
alias kdcj='kd cronjob'
alias kdcrd='kd crd'

alias ka='k apply'
alias kaf='k apply -f'

alias kl='k logs -f'
alias kex='k exec -it'
alias krmp='k delete --force --grace-period=0 po'

alias ks='k -n kube-system'
alias ksg='ks get'
alias ksgd='ksg deploy'
alias ksgp='ksg pods'
alias ksgs='ksg svc'
alias ksge='ksg events'
alias ksgds='ksg daemonset'
alias ksgss='ksg sts'
alias ksgj='ksg job'
alias ksgcj='ksg cronjob'

alias ksd='ks describe'
alias ksdd='ksd deploy'
alias ksdp='ksd pods'
alias ksds='ksd svc'
alias ksdds='ksd daemonset'
alias ksdss='ksd sts'
alias ksdj='ksd job'
alias ksdcj='ksd cronjob'

alias ksa='ks apply'
alias ksaf='ks apply -f'

alias ksl='ks logs -f'
alias ksex='ks exec -it'
alias ksrmp='ks delete --force --grace-period=0 po'

alias kr='k run --restart=Never --dry-run=client -o yaml'
EOF

source ~/.bashrc
