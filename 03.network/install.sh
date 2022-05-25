#!/bin/bash

NETWORK_PLUGIN=$(yq '.k8s.networkPlugin' ../config.yaml)

kubectl apply -f ./$NETWORK_PLUGIN.yaml

kubectl apply -f ./multus-daemonset-thick-plugin.yml
