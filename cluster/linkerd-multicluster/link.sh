#!/bin/sh

echo "=== Linking clusters through linkerd ==="
for cluster in "$@"
do
  externalControlPlaneIp=$(docker inspect $cluster-control-plane --format "{{ .NetworkSettings.Networks.kind.IPAddress }}")
  echo "$externalControlPlaneIp"
  for target in "$@";
  do
    if [ "$cluster" = "$target" ]; then continue; fi;
    echo "$cluster ($externalControlPlaneIp) => $target";
    linkerd multicluster --context=kind-$cluster link-gen \
      --cluster-name=$cluster \
      --api-server-address="https://$externalControlPlaneIp:6443" \
      | kubectl --context=kind-$target apply -f -
  done
done
