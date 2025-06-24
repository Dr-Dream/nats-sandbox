#!/bin/sh

for cluster in "$@"
do
  kube_context="kind-$cluster"
  helm --kube-context="$kube_context" -n linkerd-multicluster uninstall linkerd-multicluster
done


