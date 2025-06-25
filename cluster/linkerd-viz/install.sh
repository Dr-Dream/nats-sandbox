#!/bin/sh

set -e
LINKERD_REPO=linkerd-edge
CWD=$(dirname "$0")

for cluster in "$@"
do
  kube_context="k3d-$cluster"
  echo "=== Installing linkerd viz "
  helm --kube-context="$kube_context" -n linkerd-viz upgrade --install --create-namespace --wait\
    --set 'prometheus.enabled=false' \
    --set 'prometheusUrl=http://prometheus-kube-prometheus-prometheus.prometheus:9090' \
    --set 'grafana.url=prometheus-grafana.prometheus' \
    linkerd-viz "$LINKERD_REPO/linkerd-viz"
  echo "=== Installing linkerd monitors"
  kubectl --context "$kube_context" -n prometheus apply -f "$CWD/monitors.yml"

done


