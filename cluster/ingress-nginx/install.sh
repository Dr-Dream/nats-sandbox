#!/bin/sh

set -e

      # prometheus.io/scrape: "true"
      # prometheus.io/port: "10254

for cluster in "$@"
do
  kube_context="kind-$cluster"
  helm --kube-context="$kube_context" upgrade --install --wait \
    -n ingress-nginx --create-namespace \
    --set "controller.service.enabled=true" \
    --set "controller.service.targetPorts.http=http" \
    --set "controller.service.targetPorts.https=https" \
    --set "controller.service.externalTrafficPolicy=Cluster" \
    --set "controller.service.type=LoadBalancer" \
    --set "controller.service.ports.nats-gw=7222" \
    --set "controller.service.ports.nats-xr=7223" \
    --set "controller.service.targetPorts.nats-gw=nats-gw" \
    --set "controller.service.targetPorts.nats-xr=nats-xr" \
    --set "tcp.7222=nats/$cluster-gw-nats:7222" \
    --set "tcp.7223=nats/xr-js-nats:7223" \
    --set "controller.metrics.enabled=true" \
    --set "controller.metrics.service.annotations.prometheus\.io\/scrape=\"true\"" \
    --set "controller.metrics.service.annotations.prometheus\.io\/port=\"10254\"" \
    --set "controller.podAnnotations.linkerd\.io\/inject=enabled" \
    --set-json "controller.podAnnotations.config\.linkerd\.io\/opaque-ports=\"7222,7223\"" \
    ingress-nginx ingress-nginx/ingress-nginx
done
