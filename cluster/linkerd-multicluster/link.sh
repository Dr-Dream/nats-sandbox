#!/bin/sh

echo "=== Linking clusters through linkerd ==="
for cluster in "$@"
do
  for target in "$@";
  do
    if [ "$cluster" = "$target" ]; then continue; fi;
    echo "$cluster ($externalControlPlaneIp) => $target";
    linkerd multicluster --context=k3d-$cluster link-gen \
      --cluster-name=$cluster \
      --api-server-address "https://k3d-$cluster-server-0:6443" \
      --gateway-addresses "k3d-$cluster-server-0" \
      | kubectl --context=k3d-$target apply -f -
  done
done
