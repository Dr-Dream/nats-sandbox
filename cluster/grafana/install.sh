#!/bin/sh


for cluster in "$@"
do
  kube_context="kind-$cluster"
  cluster_domain=$cluster.local
  helm --kube-context="$kube_context" upgrade --install \
    -n prometheus --create-namespace \
    --set "grafana.ingress.enabled=true" \
    --set "grafana.ingress.hosts={grafana.$cluster_domain}" \
    --set "grafana.ingress.ingressClassName=nginx" \
    prometheus prometheus-community/kube-prometheus-stack
done
