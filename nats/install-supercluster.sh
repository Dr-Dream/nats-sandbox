#!/bin/sh

#Should be declared in all clusters
GATEWAY_PORT=7222
GATEWAY_USER=gwu
GATEWAY_PASSWORD=gwp

gatewayRoutes=""

for cluster in "$@"
do
    kubectl config use-context "kind-$cluster"
    externalIp=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "${gatewayRoutes}" ]; then gatewayRoutes="$gatewayRoutes,"; fi;
    echo "cluster=$externalIp";
    gatewayRoutes="$gatewayRoutes{\"name\":\"$cluster\",\"url\":\"nats://$GATEWAY_USER:$GATEWAY_PASSWORD@$externalIp:$GATEWAY_PORT\"}";
done

echo "config.gateway.merge.gateways=[$gatewayRoutes]"


for cluster in "$@"
do
    kubectl config use-context "kind-$cluster"
    externalIp=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "=== Installing nats seed servers $cluster"
    helm upgrade --install \
      -n nats --create-namespace \
      -f ./nats/cluster.yaml \
      --set "config.cluster.merge.name=$cluster" \
      --set "config.gateway.merge.name=$cluster" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      "$cluster" nats/nats

    echo "=== Installing JetStream nodes ==="

    helm upgrade --install \
      -n nats --create-namespace \
      -f ./nats/jetstream.yaml \
      --set 'natsBox.enabled=false' \
      --set "config.cluster.merge.name=$cluster" \
      --set "config.cluster.merge.routes={nats://$cluster-js-nats-0.$cluster-js-nats-headless:6222,nats://$cluster-js-nats-1.$cluster-js-nats-headless:6222,nats://$cluster-js-nats-2.$cluster-js-nats-headless:6222,nats://$cluster-nats:6222}" \
      --set "config.gateway.merge.name=$cluster" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      "$cluster-js" nats/nats

    echo "=== Creating gateway nodes for $cluster"
    helm upgrade --install \
      -n nats --create-namespace \
      -f ./nats/gateway.yaml \
      --set 'natsBox.enabled=false' \
      --set "config.cluster.merge.name=$cluster" \
      --set "config.cluster.merge.routes={nats://$cluster-gw-nats-0.$cluster-gw-nats-headless:6222,nats://$cluster-gw-nats-1.$cluster-gw-nats-headless:6222,nats://$cluster-gw-nats-2.$cluster-gw-nats-headless:6222,nats://$cluster-nats:6222}" \
      --set "config.gateway.merge.name=$cluster" \
      --set "config.gateway.merge.advertise=$externalIp:7222" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      --set-json "config.gateway.merge.authorization={\"user\":\"$GATEWAY_USER\",\"password\":\"$GATEWAY_PASSWORD\"}" \
      "$cluster-gw" nats/nats
done
