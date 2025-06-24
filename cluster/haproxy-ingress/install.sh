#!/bin/sh

set -e
CWD=$(dirname "$0")

#    --set "controller.service.ports.nats-gw=7222" \

for cluster in "$@"
do
  kube_context="k3d-$cluster"

  echo "== Check namespace exits "
  if ! kubectl --context="$kube_context" get ns haproxy-ingress; then
    echo "== Creating namespace"
    kubectl --context="$kube_context" create namespace haproxy-ingress
  fi
  echo "=== injecting linkerd into namespace"
  kubectl --context="$kube_context" annotate namespace haproxy-ingress linkerd.io/inject=enabled

  #controller.podAnnotations
  #controller.service.annotations

  echo "=== Installing haproxy ingress controller "
  helm --kube-context="$kube_context" -n haproxy-ingress upgrade --install --create-namespace \
    --set 'controller.ingressClassResource.default=true' \
    --set 'controller.service.type=LoadBalancer' \
    --set 'controller.service.tcpPorts[0].name=nats-gw' \
    --set 'controller.service.tcpPorts[0].port=7222' \
    --set 'controller.service.tcpPorts[0].targetPort=7222' \
    --set 'controller.podMonitor.enabled=true' \
    --set 'controller.serviceMonitor.enabled=true' \
    --set-json "controller.podAnnotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
    --set-json "controller.service.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
    haproxy-ingress haproxytech/kubernetes-ingress
done


