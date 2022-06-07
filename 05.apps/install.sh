#!/bin/bash

K8S_DOMAIN=$(yq '.k8s.domain' ../config.yaml)
sed "s/K8S_DOMAIN/$K8S_DOMAIN/g" kubernetes-dashboard.yaml.template > kubernetes-dashboard.yaml
sed "s/K8S_DOMAIN/$K8S_DOMAIN/g" harbor.yaml.template > harbor.yaml

METRIC_SERVER_ENABLED=$(yq '.apps.metrics-server.enabled' ../config.yaml)
if [ $METRIC_SERVER_ENABLED == "true" ]; then
  helm install metrics-server metrics-server -f metrics-server.yaml -n kube-system
fi

DASHBOARD_ENABLED=$(yq '.apps.dashboard.enabled' ../config.yaml)
if [ $DASHBOARD_ENABLED == "true" ]; then
  helm install kubernetes-dashboard kubernetes-dashboard -f kubernetes-dashboard.yaml -n kube-system
  kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
fi

INGRESS_NGINX_ENABLED=$(yq '.apps.ingress-nginx.enabled' ../config.yaml)
if [ $INGRESS_NGINX_ENABLED == "true" ]; then
  kubectl create namespace ingress-nginx
  helm install ingress-nginx ingress-nginx -f ingress-nginx.yaml -n ingress-nginx
fi

HARBOR_ENABLED=$(yq '.apps.harbor.enabled' ../config.yaml)
if [ $HARBOR_ENABLED == "true" ]; then
  kubectl create namespace harbor
  helm install harbor harbor-helm -f harbor.yaml -n harbor
fi

# after install
IPADDR=$(yq '.k8s.clusterIP' ../config.yaml)

URL_DASHBOARD=$(yq '.ingress.hosts[0]' ./kubernetes-dashboard.yaml)
URL_HARBOR=$(yq '.expose.ingress.hosts.core' ./harbor.yaml)

echo "Add below resolv info to /etc/hosts: "
echo $IPADDR $URL_DASHBOARD $URL_HARBOR
