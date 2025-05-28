#!/bin/sh

http_port_base=81
https_port_base=444


cluster_index=$1
cluster=$2
cluster_http_port=$((http_port_base + cluster_index))
cluster_https_port=$((https_port_base + cluster_index))

cluster_domain=$cluster.local

echo "======Installing requirements $1-$2 ($cluster_domain http/$cluster_http_port https/$cluster_https_port) "
kubectl config use-context "kind-$cluster"

echo "===Installing cert-manager"
helm upgrade --install \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.2 \
  --set crds.enabled=true \
  cert-manager jetstack/cert-manager

echo "===Installing ingress controller"
helm upgrade --install \
  -n ingress-nginx --create-namespace \
  --set "controller.service.enabled=true" \
  --set "controller.service.targetPorts.http=http" \
  --set "controller.service.targetPorts.https=https" \
  --set "controller.service.externalTrafficPolicy=Cluster" \
  --set "controller.service.type=LoadBalancer" \
  --set "controller.service.ports.nats-gw=7222" \
  --set "controller.service.targetPorts.nats-gw=nats-gw" \
  --set "tcp.7222=nats/$cluster-gw-nats:7222" \
  ingress-nginx ingress-nginx/ingress-nginx

#  --set "controller.service.nodePorts.http=$cluster_http_port" \
#  --set "controller.service.nodePorts.https=$cluster_https_port" \


echo "===Installing prometheus stack (grafana.$cluster_domain)"
helm upgrade --install \
  -n prometheus --create-namespace \
  --set "grafana.ingress.enabled=true" \
  --set "grafana.ingress.hosts={grafana.$cluster_domain}" \
  --set "grafana.ingress.ingressClassName=nginx" \
  prometheus prometheus-community/kube-prometheus-stack

echo "===Installing nats"
#export CLUSTER_NAME=$cluster
#export CLUSTER_DOMAIN=$cluster_domain
#envsubst < ./nats/cluster.yaml |

NATS_EXTERNAL_IP=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "!!!!! EXTERNAL_IP=$NATS_EXTERNAL_IP"
