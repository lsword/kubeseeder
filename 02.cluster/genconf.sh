#!/bin/bash

K8S_VERSION=$(yq '.k8s.version' ../config.yaml)
K8S_CLUSTER_DOMAIN=cluster.$(yq '.k8s.domain' ../config.yaml)

sed "s/K8S_VERSION/$K8S_VERSION/g" kubeadm.yaml.template | sed "s/K8S_CLUSTER_DOMAIN/$K8S_CLUSTER_DOMAIN/g" > kubeadm.yaml
