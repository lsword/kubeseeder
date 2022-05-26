# kubeseeder

[![License](http://img.shields.io/badge/license-apache%20v2-blue.svg)](https://github.com/openpitrix/openpitrix/blob/master/LICENSE)

----

kubeseeder是一个kubernetes安装工具，主要包括以下功能：

- 支持k8s集群安装。
- 支持单节点k8s，快速部署用于个人学习和测试的k8s环境。
- 支持k8s集群的离线部署及升级。
- 支持离线安装包的制作（目前支持centos7, ubuntu）。
- 支持主流网络插件（calico, flannel）。
- 包含集群安装后需要部署的常用软件，包括ingress-nginx、harbor、dashboard等。

----

## k8s节点配置要求

master节点:

  - 最低配置

  | cpu  | memory | disk        |
  | ---- | ------ | ----------- |
  | 4c   | 4G     | 30G on /var |

  - 建议配置

  | cpu  | memory | disk         |
  | ---- | ------ | ------------ |
  | 8c   | 16G    | 100G on /var |

node节点:

  - 最低配置

  | cpu  | memory | disk         |
  | ---- | ------ | ------------ |
  | 8c   | 16G    | 100G on /var |

  - 建议配置

  | cpu  | memory | disk         |
  | ---- | ------ | ------------ |
  | 32c  | 128G   | 300G on /var |

## 网络

支持calico、flannel等主流网络插件。

基于multus插件为pod提供多网卡支持。

## 存储

基于local-path-provisioner提供本地存储支持。（主要针对单节点集群环境）

基于nfs-subdir-external-provisioner提供NFS存储支持。

## 使用说明

### 运行环境

此工具需要在centos7.x环境中以root账号运行。

需要主机能够联网。

需要安装docker。

### 配置

kubeseeder使用config.yaml作为配置文件。

正式使用前，根据config.yaml.template创建config.yaml文件。

~~~
cp config.yaml.template config.yaml
~~~

通过config.yaml文件指定了k8s版本、网络插件、存储插件、应用软件、工具软件的相关信息。

以下为config.yaml示例：

~~~
os:
  release: centos
  version: 7.9.2009
k8s:
  version: 1.22.7
  domainName: cluster.k8s.ebupt.com
  networkPlugin: calico
  installMode: offline
  clusterIP: 10.1.69.217
  singleNode: true
networkPlugin:
  calico:
    version: 3.17
  flannel:
    version: 0.16.3
storage:
  nfs:
    server: nfs.k8s.ebupt.com
    path: /var/nfsdata
apps:
  metrics-server:
    version: 0.6.1
    chartVersion: 3.8.2
  ingress-nginx:
    version: 1.1.3
    chartVersion: 4.0.19
  dashboard:
    version: 2.5.1
    chartVersion: 5.5.1
  harbor:
    version: 2.4.2
    chartVersion: 1.8.2
  kube-prometheus:
    version: 0.56.2
    chartVersion: 35.2.0
tools:
  helm:
    version: 3.8.2
~~~

### 安装前准备

配置好config.yaml后，执行prepare.sh，下载相关文件。在离线模式下，可以生成完整的离线安装包。

### 制作离线安装包

如果已有的离线包支持的k8s版本和操作系统版本不满足需求，可以根据需要自制离线安装包。
配置好config.yaml后，执行genoffline.sh生成离线安装包。
离线安装包数据保存在offline目录中。

### 安装k8s集群

- 初始化节点

在每个k8s节点上，运行01.base中的init.sh，对k8s节点进行初始化。

- 初始化集群

在k8s的第一个master节点上，运行02.cluster中的init.sh，初始化k8s集群。

- 安装网络插件

在k8s的第一个master节点上，运行03.network中的install.sh，安装网络插件。
目前只支持calico和flannel。

- 安装存储插件

在k8s的第一个master节点上，运行04.storage中的install.sh，安装存储插件。
目前只支持NFS。

- 安装应用软件

在k8s的第一个master节点上，运行05.storage中的install.sh，安装应用软件。

名称|用途|版本
---|---|---
metrics-server|指标服务器|0.6.1
ingress-nginx|应用代理|1.1.3
dashboard|k8s控制台|2.5.1
harbor|镜像服务器|2.4.2

- 添加master

在k8s的其余master节点上，执行02.cluster中的addmaster.sh，添加master。

- 添加node

在k8s的node节点上，执行02.cluster中的addnode.sh，添加node。

### 升级k8s集群

- 升级第一个master

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh firstmaster
~~~

- 升级其他master

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh othermaster
~~~

- 升级node

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh node
~~~
