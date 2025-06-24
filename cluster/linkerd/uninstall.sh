#!/bin/sh

for cluster in "$@"
do
  kube_context="k3d-$cluster"
  helm --kube-context "$kube_context" uninstall linkerd-crds
  helm --kube-context="$kube_context" -n linkerd uninstall linkerd-control-plane
  helm --kube-context="$kube_context" -n linkerd-viz uninstall linkerd-viz
done


