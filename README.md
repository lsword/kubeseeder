# kubeseeder

[![License](http://img.shields.io/badge/license-apache%20v2-blue.svg)](https://github.com/openpitrix/openpitrix/blob/master/LICENSE)

----

kubeseeder是一个基于shell脚本实现的kubernetes安装工具，主要包括以下功能：

- 支持k8s集群安装。
- 支持单节点k8s，快速部署用于个人学习和测试的k8s环境。
- 支持k8s集群的离线部署及升级。
- 支持离线安装包的制作（目前支持centos7, ubuntu）。
- 支持主流网络插件（calico, flannel）。
- 基于local-path-provisioner提供本地存储支持。（主要针对单节点集群环境） 基于nfs-subdir-external-provisioner提供NFS存储支持。
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

## 配置

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
  version: 1.23.6
  domain: myk8s.com
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
  localPath:
    path: /opt/local-path-provisioner
  nfs:
    server: nfs.myk8s.com
    path: /var/nfsdata
apps:
  metrics-server:
    version: 0.6.1
    chartVersion: 3.8.2
    enabled: true
  ingress-nginx:
    version: 1.1.3
    chartVersion: 4.0.19
    enabled: true
  dashboard:
    version: 2.5.1
    chartVersion: 5.5.1
    enabled: true
  harbor:
    version: 2.4.2
    chartVersion: 1.8.2
    enabled: true
tools:
  helm:
    version: 3.8.2
  k9s:
    version: 0.25.18
~~~

### os

| Name         | Description                      | Value       |
| ------------ | -------------------------------- | ----------- |
| `os.release` | Linux发行版名称（centos、ubuntu）| `centos`    |
| `os.version` | Linux发行版版本                  | `7.9.2009`  |

### k8s

| Name                | Description   | Value          |
| ------------------- | ------------- | -------------- |
| `k8s.version`       | k8s版本       | `1.23.6`       |
| `k8s.domain`        | k8s域名       | `myk8s.com`    |
| `k8s.networkPlugin` | k8s网络插件   | `calico`       |
| `k8s.installMode`   | k8s安装模式   | `offline`      |
| `k8s.clusterIP`     | k8s集群IP地址 | `10.1.69.217`  |
| `k8s.singleNode`    | k8s单节点模式 | `true`         |

### networkPlugin

| Name                            | Description | Value     |
| ------------------------------- | ----------- | --------- |
| `networkPlugin.calico.version`  | calico版本  | `3.17`    |
| `networkPlugin.flannel.version` | flannel版本 | `0.16.3`  |

### storage

| Name                      | Description                           | Value                          |
| ------------------------- | ------------------------------------- | ------------------------------ |
| `storage.localPath.path`  | local-path-provisioner使用的本地路径  | `/opt/local-path-provisioner`  |
| `storage.nfs.server`      | nfs服务器地址                         | `nfs.myk8s.com`                |
| `storage.nfs.path`        | nfs服务器路径                         | `/var/nfsdata`                 |

### apps

| Name                                | Description               | Value    |
| ----------------------------------- | ------------------------- | -------- |
| `apps.metrics-server.version`       | metrics-server应用版本    | `0.6.1`  |
| `apps.metrics-server.chartVersion`  | metrics-server的chart版本 | `3.8.2`  |
| `apps.metrics-server.enabled`       | 是否安装metrics-server    | `true`   |
| `apps.ingress-nginx.version`        | ingress-nginx应用版本     | `1.1.3`  |
| `apps.ingress-nginx.chartVersion`   | ingress-nginx的chart版本  | `4.0.19` |
| `apps.ingress-nginx.enabled`        | 是否安装ingress-nginx     | `true`   |
| `apps.dashboard.version`            | dashboard应用版本         | `0.6.1`  |
| `apps.dashboard.chartVersion`       | dashboard的chart版本      | `3.8.2`  |
| `apps.dashboard.enabled`            | 是否安装dashboard         | `true`   |
| `apps.harbor.version`               | harbor应用版本            | `2.5.1`  |
| `apps.harbor.chartVersion`          | harbor的chart版本         | `5.5.1`  |
| `apps.harbor.enabled`               | 是否安装harbor            | `true`   |

### tools

| Name                 | Description | Value     |
| -------------------- | ----------- | --------- |
| `tools.helm.version` | helm版本    | `3.8.2`   |
| `tools.k9s.version`  | k9s版本     | `0.25.18` |

## 离线安装k8s

使用kubeseeder离线安装k8s，需要按照以下步骤操作。

### 生成离线安装包

需要在centos7.x环境中以root账号执行。
需要主机能够联网。
需要安装docker。

1. 获取kubeseeder

~~~
git clone https://github.com/lsword/kubeseeder
~~~

2. 编写配置文件

基于config.yaml.template生成config.yaml配置文件，并根据需要进行修改。

~~~
cd kubeseeder
cp config.yaml.template config.yaml
vi config.yaml
~~~

3. 制作离线安装包

配置好config.yaml后，执行prepare.sh，下载相关文件，生成完整的离线安装包。


### 离线安装k8s集群

将kubeseeder目录打包。

~~~
tar cfvz kubeseeder.tgz kubeseeder
~~~

将离线安装包kubeseeder.tgz拷贝到各台离线主机并解压。

~~~
tar xfvz kubeseeder.tgz
~~~

#### 根据所在主机情况修改config.yaml。

单机模式下，将k8s.clusterIP设置为主机IP地址。

#### 按照以下顺序安装k8s的第一个master节点。

在用作第一个master节点的主机上做以下操作。

1. 初始化节点

运行01.base中的init.sh，对节点进行初始化。

2. 初始化集群

运行02.cluster中的init.sh，初始化k8s集群。

3. 安装网络插件

运行03.network中的install.sh，安装网络插件。
目前只支持calico和flannel。

4. 安装存储插件

运行04.storage中的install.sh，安装存储插件。

5. 安装应用软件

运行05.storage中的install.sh，安装应用软件。

名称|用途|版本
---|---|---
metrics-server|指标服务器|0.6.1
ingress-nginx|应用代理|1.1.3
dashboard|k8s控制台|2.5.1
harbor|镜像服务器|2.4.2

#### 按照以下顺序添加其他master节点。(根据需要)

在用作master节点的主机上做以下操作。

1. 初始化节点

运行01.base中的init.sh，对节点进行初始化。

2. 添加master

执行02.cluster中的addmaster.sh，根据提示，将当前主机添加master。

#### 按照以下顺序添加其他node节点。(根据需要)

在用作node节点的主机上做以下操作。

1. 初始化节点

运行01.base中的init.sh，对节点进行初始化。

2. 添加master

执行02.cluster中的addnode.sh，根据提示，添加node。

## 离线升级k8s集群

### 升级第一个master

在第一个master节点上执行以下操作。

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh firstmaster
~~~

### 升级其他master

在master节点上执行以下操作。

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh othermaster
~~~

### 升级node

在node节点上执行以下操作。

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh node
~~~


## 在线安装k8s

### 获取并配置kubeseeder

1. 获取kubeseeder

~~~
git clone https://github.com/lsword/kubeseeder
~~~

2. 编写配置文件

基于config.yaml.template生成config.yaml配置文件，并根据需要进行修改。

~~~
cd kubeseeder
cp config.yaml.template config.yaml
vi config.yaml
~~~

3. 将kubeseeder打包并拷贝到各台主机

将kubeseeder目录打包。

~~~
tar cfvz kubeseeder.tgz kubeseeder
~~~

将离线安装包kubeseeder.tgz拷贝到各台主机并解压。

~~~
tar xfvz kubeseeder.tgz
~~~

### 在线安装k8s集群

#### 按照以下顺序安装k8s的第一个master节点。

在用作第一个master节点的主机上做以下操作。

1. 初始化节点

运行01.base中的init.sh，对节点进行初始化。

2. 初始化集群

运行02.cluster中的init.sh，初始化k8s集群。

3. 安装网络插件

运行03.network中的install.sh，安装网络插件。
目前只支持calico和flannel。

4. 安装存储插件

运行04.storage中的install.sh，安装存储插件。

5. 安装应用软件

运行05.storage中的install.sh，安装应用软件。

名称|用途|版本
---|---|---
metrics-server|指标服务器|0.6.1
ingress-nginx|应用代理|1.1.3
dashboard|k8s控制台|2.5.1
harbor|镜像服务器|2.4.2

#### 按照以下顺序添加其他master节点。(根据需要)

在用作master节点的主机上做以下操作。

1. 初始化节点

运行01.base中的init.sh，对节点进行初始化。

2. 添加master

执行02.cluster中的addmaster.sh，根据提示，将当前主机添加master。

#### 按照以下顺序添加其他node节点。(根据需要)

在用作node节点的主机上做以下操作。

1. 初始化节点

运行01.base中的init.sh，对节点进行初始化。

2. 添加master

执行02.cluster中的addnode.sh，根据提示，添加node。

## 在线升级k8s集群

### 升级第一个master

在第一个master节点上执行以下操作。

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh firstmaster
~~~

### 升级其他master

在master节点上执行以下操作。

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh othermaster
~~~

### 升级node

在node节点上执行以下操作。

进入02.cluster目录，执行以下升级命令：

~~~
./upgrade.sh node
~~~


