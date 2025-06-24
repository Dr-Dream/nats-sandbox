#!/bin/sh


set -e


LINKERD_REPO=linkerd-edge

for cluster in "$@"
do
  kube_context="k3d-$cluster"
  echo "=== Installs linkerd CRDs ==="
  helm --kube-context "$kube_context" upgrade --install \
    -n linkerd --create-namespace --set installGatewayAPI=true \
    linkerd-crds "$LINKERD_REPO/linkerd-crds"
  echo "=== Installing linkerd control-plane "
  helm --kube-context="$kube_context" -n linkerd upgrade --install --create-namespace \
    --set identity.externalCA=true \
    --set identity.issuer.scheme=kubernetes.io/tls \
    --set 'prometheusUrl=http://prometheus-kube-prometheus-prometheus.prometheus:9090' \
    --set 'disableHeartBeat=true' \
    --wait \
    linkerd-control-plane "$LINKERD_REPO/linkerd-control-plane"
done


