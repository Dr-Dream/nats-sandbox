#!/bin/sh


for cluster in "$@"
do
#    --set "grafana.ingress.ingressClassName=nginx" \
  kube_context="k3d-$cluster"
  cluster_domain=$cluster.local
  helm --kube-context="$kube_context" upgrade --install \
    -n prometheus --create-namespace \
    --set "grafana.ingress.enabled=true" \
    --set "grafana.ingress.hosts={grafana.$cluster_domain}" \
    prometheus prometheus-community/kube-prometheus-stack
done
