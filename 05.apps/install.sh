#!/bin/bash

K8S_DOMAIN=$(yq '.k8s.domain' ../config.yaml)
sed "s/K8S_DOMAIN/$K8S_DOMAIN/g" kubernetes-dashboard.yaml.template > kubernetes-dashboard.yaml
sed "s/K8S_DOMAIN/$K8S_DOMAIN/g" harbor.yaml.template > harbor.yaml

helm install metrics-server metrics-server -f metrics-server.yaml -n kube-system

helm install kubernetes-dashboard kubernetes-dashboard -f kubernetes-dashboard.yaml -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

kubectl create namespace ingress-nginx
helm install ingress-nginx ingress-nginx -f ingress-nginx.yaml -n ingress-nginx

kubectl create namespace harbor
helm install harbor harbor-helm -f harbor.yaml -n harbor

# after install
IPADDR=$(yq '.k8s.clusterIP' ../config.yaml)

URL_DASHBOARD=$(yq '.ingress.hosts[0]' ./kubernetes-dashboard.yaml)
URL_HARBOR=$(yq '.expose.ingress.hosts.core' ./harbor.yaml)

echo "Add below resolv info to /etc/hosts: "
echo $IPADDR $URL_DASHBOARD $URL_HARBOR
