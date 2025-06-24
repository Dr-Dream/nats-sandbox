#!/bin/sh

CWD=$(dirname "$0")

for cluster in "$@"
do
  kube_context="k3d-$cluster"
  helm --kube-context="$kube_context" -n linkerd-viz uninstall linkerd-viz
  kubectl --context "$kube_context" -n prometheus delete -f "$CWD/monitors.yml"
done


