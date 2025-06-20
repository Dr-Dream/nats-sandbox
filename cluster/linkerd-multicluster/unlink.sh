#!/bin/sh

echo "===Unlinking clusters through linkerd ==="
for cluster in "$@"
do
  externalControlPlaneIp=$(docker inspect $cluster-control-plane --format "{{ .NetworkSettings.Networks.kind.IPAddress }}")
  echo "$externalControlPlaneIp"
  for target in "$@";
  do
     if [ "$cluster" = "$target" ]; then continue; fi;
     echo "$cluster ($externalControlPlaneIp) => $target";
     linkerd multicluster --context=kind-$cluster link-gen \
      --cluster-name=$target \
      | kubectl --context=kind-$cluster delete -f -
     linkerd multicluster --context=kind-$cluster link \
      --cluster-name=$target \
      | kubectl --context=kind-$cluster delete -f -
  done
done
