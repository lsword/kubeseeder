#!/bin/bash

#==================================================================================================================
# Read Config
#------------------------------------------------------------------------------------------------------------------
OS_RELEASE=$(yq '.os.release' ../config.yaml)

if [ $OS_RELEASE == "centos" ]; then
  #关闭防火墙
  systemctl stop firewalld
  systemctl disable firewalld

  #禁用SELINUX
  setenforce 0
  sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
  sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
  sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux
  sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config

  # 加载ipvs模块
  KERNEL_VERSION=`uname -r`
  ipvs_modules_dir="/usr/lib/modules/$KERNEL_VERSION/kernel/net/netfilter/ipvs/"
  echo $ipvs_modules_dir
  echo '' > /etc/modules-load.d/ip_vs.conf
  for i in $(ls $ipvs_modules_dir | sed 's/\.ko.xz//g'); do
    /sbin/modinfo -F filename $i &> /dev/null
    if [ $? -eq 0 ]; then
      /sbin/modprobe $i
    fi
    echo $i >> /etc/modules-load.d/ip_vs.conf
  done
  systemctl enable --now systemd-modules-load.service
elif [ $OS_RELEASE == "ubuntu" ]; then
  #关闭防火墙
  systemctl stop ufw
  systemctl disable ufw

  # 加载ipvs模块
  for i in $(ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*");do echo $i; /sbin/modinfo -F filename $i >/dev/null 2>&1 && /sbin/modprobe $i; done
  ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*" >> /etc/modules
else
  echo "Does not support for $OS_RELEASE"
  exit 1
fi

#关闭swap
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

#内核参数
tee  /etc/sysctl.d/k8s.conf <<EOF
fs.file-max=52706963
fs.nr_open=52706963
fs.may_detach_mounts = 1
fs.inotify.max_user_instances = 8192
fs.aio-max-nr = 1048576
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.netfilter.nf_conntrack_max=2310720
net.core.rmem_default = 16777216
net.core.rmem_max = 16777216
net.core.wmem_default = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 65535
net.core.somaxconn = 65535
net.ipv4.ip_forward=1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_syncookies = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
vm.max_map_count = 262144
EOF

sysctl --system

echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "* soft nproc 65536"  >> /etc/security/limits.conf
echo "* hard nproc 65536"  >> /etc/security/limits.conf
echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
echo "* hard memlock  unlimited"  >> /etc/security/limits
