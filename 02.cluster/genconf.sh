#!/bin/bash

#K8S_VERSION=$(yq '.k8s.version' ../config.yaml)
#K8S_CLUSTER_DOMAIN=cluster.$(yq '.k8s.domain' ../config.yaml)

#sed "s/K8S_VERSION/$K8S_VERSION/g" kubeadm.yaml.template | sed "s/K8S_CLUSTER_DOMAIN/$K8S_CLUSTER_DOMAIN/g" > kubeadm.yaml

kubeadm config print init-defaults | yq -s '.kind'

# REF: https://pkg.go.dev/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta3

export K8S_VERSION=$(yq '.k8s.version' ../config.yaml)
export K8S_CLUSTER_DOMAIN=cluster.$(yq '.k8s.domain' ../config.yaml)
export K8S_CLUSTER_PORT=6443
export K8S_CONTROLPLANE_ENDPOINT=$K8S_CLUSTER_DOMAIN:$K8S_CLUSTER_PORT

yq '.kubernetesVersion = env(K8S_VERSION) |
    .clusterName = "kubernetes" |
    .imageRepository = "registry.cn-hangzhou.aliyuncs.com/google_containers" |
    .certificatesDir = "/etc/kubernetes/pki" |
    .controlPlaneEndpoint = env(K8S_CONTROLPLANE_ENDPOINT) |
    .apiServer.extraArgs.authorization-mode = "Node,RBAC" | .apiServer.extraArgs.authorization-mode style="double" |
    .apiServer.extraArgs.service-node-port-range = "30000-65530" |
    .apiServer.extraArgs.enable-admission-plugins = "NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,Priority" |
    .apiServer.certSANs[0] = env(K8S_CLUSTER_DOMAIN) |
    .apiServer.certSANs[1] = "10.96.0.1" |
    .apiServer.certSANs[2] = "127.0.0.1" |
    .apiServer.certSANs[3] = "kubernetes" |
    .apiServer.certSANs[4] = "kubernetes.default" |
    .apiServer.certSANs[5] = "kubernetes.default.svc" |
    .apiServer.certSANs[6] = "kubernetes.default.svc.cluster.local" |
    .apiServer.extraVolumes[0].hostPath = "/etc/localtime" |
    .apiServer.extraVolumes[0].mountPath = "/etc/localtime" |
    .apiServer.extraVolumes[0].name = "timezone" |
    .apiServer.extraVolumes[0].readOnly = true  |
    .controllerManager.extraArgs.bind-address = "0.0.0.0" |
    .controllerManager.extraVolumes[0].hostPath = "/etc/localtime" |
    .controllerManager.extraVolumes[0].mountPath = "/etc/localtime" |
    .controllerManager.extraVolumes[0].name = "timezone" |
    .controllerManager.extraVolumes[0].readOnly = true  |
    .scheduler.extraArgs.bind-address = "0.0.0.0" |
    .scheduler.extraVolumes[0].hostPath = "/etc/localtime" |
    .scheduler.extraVolumes[0].mountPath = "/etc/localtime" |
    .scheduler.extraVolumes[0].name = "timezone" |
    .scheduler.extraVolumes[0].readOnly = true |
    .etcd.local.dataDir = "/var/lib/etcd" |
    .etcd.local.serverCertSANs[0] = env(K8S_CLUSTER_DOMAIN) |
    .networking.podSubnet = "10.244.0.0/16" |
    .networking.serviceSubnet = "10.96.0.0/12" |
    .networking.dnsDomain = "cluster.local"

' ClusterConfiguration.yml > ClusterConfiguration.yaml

yq '.localAPIEndpoint.advertiseAddress = "0.0.0.0" |
    del(.nodeRegistration.name)
' InitConfiguration.yml > InitConfiguration.yaml

# REF: https://pkg.go.dev/k8s.io/kubelet@v0.25.0/config/v1beta1#KubeletConfiguration

yq e -n \
   '.apiVersion = "kubelet.config.k8s.io/v1beta1" |
    .kind = "KubeletConfiguration" |
    .cgroupDriver = "systemd" |
    .streamingConnectionIdleTimeout = "0s" |
    .syncFrequency = "30s" |
    .volumeStatsAggPeriod = "30s" |
    .runtimeRequestTimeout = "60s" |
    .cpuManagerPolicy = "static" |
    .staticPodPath = "/etc/kubernetes/manifests" |
    .authentication.anonymous.enabled = false |
    .authentication.webhook.cacheTTL = "0s" |
    .authentication.webhook.enabled = true |
    .authentication.x509.clientCAFile = "/etc/kubernetes/pki/ca.crt" |
    .evictionHard."memory.available" = "500Mi" | .evictionHard."memory.available" style="double" |
    .evictionHard."nodefs.available" = "10%" | .evictionHard."nodefs.available" style="double" |
    .kubeReserved.cpu = "200m" | .kubeReserved.cpu style="double" |
    .kubeReserved.memory = "500Mi" | .kubeReserved.memory style="double" |
    .systemReserved.cpu = "200m" | .systemReserved.cpu style="double" |
    .systemReserved.memory = "500Mi" | .systemReserved.memory style="double"
' > KubeletConfiguration.yaml

# REF: https://pkg.go.dev/k8s.io/kube-proxy/config/v1alpha1#KubeProxyConfiguration

yq e -n \
   '.apiVersion = "kubeproxy.config.k8s.io/v1alpha1" |
    .kind = "KubeProxyConfiguration" |
    .mode = "ipvs"
' > KubeProxyConfiguration.yaml

# kubeadm.yaml

yq InitConfiguration.yaml ClusterConfiguration.yaml KubeletConfiguration.yaml KubeProxyConfiguration.yaml > kubeadm.yaml

# clean

rm -rf InitConfiguration.yaml ClusterConfiguration.yaml KubeletConfiguration.yaml KubeProxyConfiguration.yaml InitConfiguration.yml ClusterConfiguration.yml
