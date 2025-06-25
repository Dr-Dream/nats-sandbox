#!/bin/sh


set -e
CWD=$(dirname "$0")
#Should be declared in all clusters
GATEWAY_PORT=7222
XR_GATEWAY_PORT=7223
GATEWAY_USER=gwu
GATEWAY_PASSWORD=gwp

baseGatewayRoutes=""
xrGwRoutes=""
xrClusterRoutes=""

sep=""

for cluster in "$@"
do
    externalIp="k3d-$cluster-agent-0"

    echo "$cluster external ip=$externalIp";
    baseGatewayRoutes="$baseGatewayRoutes$sep{\"name\":\"$cluster\",\"url\":\"nats://$GATEWAY_USER:$GATEWAY_PASSWORD@$externalIp:7222\"}"
    xrGwRoutes="$xrGwRoutes$sep""\"nats://$GATEWAY_USER:$GATEWAY_PASSWORD@xr-js-nats-$cluster:$GATEWAY_PORT\""
    sep=","
done

for cluster in "$@"
do
    kube_context="k3d-$cluster"
    echo "== Check namespace exits "
    if ! kubectl --context="$kube_context" get ns nats; then
      echo "== Creating namespace"
      kubectl --context="$kube_context" create namespace nats
    fi
    echo "=== injecting linkerd into namespace"
    kubectl --context="$kube_context" annotate namespace nats linkerd.io/inject=enabled

    externalIp="k3d-$cluster-server-0"

    seedRoutes="nats://$cluster-nats-0.$cluster-nats-headless:6222,nats://$cluster-nats-1.$cluster-nats-headless:6222,nats://$cluster-nats-2.$cluster-nats-headless:6222"
    jsRoutes="nats://$cluster-js-nats-0.$cluster-js-nats-headless:6222,nats://$cluster-js-nats-1.$cluster-js-nats-headless:6222,nats://$cluster-js-nats-2.$cluster-js-nats-headless:6222"
    gwRoutes="nats://$cluster-gw-nats-0.$cluster-gw-nats-headless:6222,nats://$cluster-gw-nats-1.$cluster-gw-nats-headless:6222,nats://$cluster-gw-nats-2.$cluster-gw-nats-headless:6222"
    xrClusterRoutes="nats://xr-js-nats-0.xr-js-nats-headless:6222,nats://xr-js-nats-1.xr-js-nats-headless:6222,nats://xr-js-nats-2.xr-js-nats-headless:6222"
    for target in "$@"
    do
      if [ "$cluster" = "$target" ]; then continue; fi;
      xrClusterRoutes="$xrClusterRoutes,nats://xr-js-nats-0.xr-js-nats-headless-$target:6222,nats://xr-js-nats-1.xr-js-nats-headless-$target:6222,nats://xr-js-nats-2.xr-js-nats-headless-$target:6222"
    done

    gatewayRoutes="$baseGatewayRoutes,{\"name\":\"xr-js\",\"url\":\"nats://xr-js-nats:7222\"}"

    echo "=== Installing nats seed servers $cluster"
    helm --kube-context="$kube_context" upgrade --install \
      -n nats --create-namespace \
      -f ./nats/cluster.yaml \
      --set-json "podTemplate.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "service.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "headlessService.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set "config.cluster.merge.name=$cluster" \
      --set "config.cluster.merge.routes={$seedRoutes}" \
      --set "config.gateway.merge.name=$cluster" \
      --set "config.gateway.merge.advertise=$externalIp:7222" \
      --set-json "config.gateway.merge.authorization={\"user\":\"$GATEWAY_USER\",\"password\":\"$GATEWAY_PASSWORD\"}" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      "$cluster" nats/nats

    echo "=== Installing JetStream nodes ==="
    helm --kube-context="$kube_context" upgrade --install \
      -n nats --create-namespace \
      -f ./nats/cluster.yaml \
      --set 'natsBox.enabled=false' \
      --set "config.merge.server_tags={dc:$cluster,az:$cluster}" \
      --set-json "podTemplate.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "service.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "headlessService.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set "config.cluster.merge.name=$cluster" \
      --set "config.cluster.merge.routes={$jsRoutes,$seedRoutes}" \
      --set "config.gateway.merge.name=$cluster" \
      --set "config.gateway.merge.advertise=$externalIp:7222" \
      --set-json "config.gateway.merge.authorization={\"user\":\"$GATEWAY_USER\",\"password\":\"$GATEWAY_PASSWORD\"}" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      --set 'config.jetstream.enabled=true' \
      --set 'config.jetstream.fileStore.enabled=true' \
      --set 'config.jetstream.fileStore.pvc.enabled=true' \
      --set 'config.jetstream.fileStore.pvc.size=2Gi' \
      "$cluster-js" nats/nats

    echo "=== Creating gateway nodes for $cluster"
    helm --kube-context="$kube_context" upgrade --install \
      -n nats --create-namespace \
      -f ./nats/cluster.yaml \
      --set 'natsBox.enabled=false' \
      --set-json "podTemplate.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "service.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "headlessService.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set "config.merge.server_tags={dc:$cluster,az:$cluster}" \
      --set "config.cluster.merge.name=$cluster" \
      --set "config.cluster.merge.routes={$gwRoutes,$jsRoutes,$seedRoutes}" \
      --set "service.ports.gateway.enabled=true" \
      --set "config.gateway.merge.name=$cluster" \
      --set "config.gateway.merge.advertise=$externalIp:7222" \
      --set-json "config.gateway.merge.authorization={\"user\":\"$GATEWAY_USER\",\"password\":\"$GATEWAY_PASSWORD\"}" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      "$cluster-gw" nats/nats

    echo "=== Installing JetStream XR nodes ==="
    helm --kube-context="$kube_context" upgrade --install \
      -n nats --create-namespace \
      -f ./nats/cluster.yaml \
      --set "config.merge.server_tags={dc:xr,az:$cluster}" \
      --set "config.serverNamePrefix=$cluster-" \
      --set 'config.jetstream.enabled=true' \
      --set 'config.jetstream.fileStore.enabled=true' \
      --set 'config.jetstream.fileStore.pvc.enabled=true' \
      --set 'config.jetstream.fileStore.pvc.size=2Gi' \
      --set "config.jetstream.merge.unique_tag=az" \
      --set-json "podTemplate.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "service.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "headlessService.merge.metadata.annotations.config\.linkerd\.io\/opaque-ports=\"4222,6222,7222,8222\"" \
      --set-json "service.merge.metadata.labels.mirror\.linkerd\.io\/exported=\"true\"" \
      --set-json "headlessService.merge.metadata.labels.mirror\.linkerd\.io\/exported=\"true\"" \
      --set "config.cluster.merge.name=xr-js" \
      --set "config.cluster.merge.routes={$xrClusterRoutes}" \
      --set "config.gateway.port=7222" \
      --set "config.gateway.merge.name=xr-js" \
      --set "service.ports.gateway.enabled=true" \
      --set-json "config.gateway.merge.gateways=[$gatewayRoutes]" \
      "xr-js" nats/nats

    export CLUSTER_NAME=$cluster
    envsubst < "$CWD/haproxy-gw-tcp.yml" | kubectl --context "$kube_context" -n nats apply -f -
    envsubst < "$CWD/haproxy-cluster-tcp.yml" | kubectl --context "$kube_context" -n nats apply -f -
    envsubst < "$CWD/xr-js.yml" | kubectl --context "$kube_context" -n nats apply -f -

done
