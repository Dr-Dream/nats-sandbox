#!/bin/sh

echo "=== Linking clusters through linkerd ==="
for cluster in "$@"
do
  externalControlPlaneIp=$(docker inspect k3d-$cluster-server-0 --format '{{ index .NetworkSettings.Networks "linkerd-idc" "IPAddress" }}')
  echo "$externalControlPlaneIp"
  for target in "$@";
  do
    if [ "$cluster" = "$target" ]; then continue; fi;
    echo "$cluster ($externalControlPlaneIp) => $target";
    linkerd multicluster --context=k3d-$cluster link-gen \
      --cluster-name=$cluster \
      --api-server-address="https://$externalControlPlaneIp:6443" \
      | kubectl --context=k3d-$target apply -f -
  done
done
