#!/bin/bash

kubectl get pod -A | grep -E "Error|Terminating|Evicted" | awk '{system("/usr/bin/kubectl delete pod -n "$1" "$2)}'
