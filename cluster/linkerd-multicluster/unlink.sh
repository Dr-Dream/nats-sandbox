#!/bin/sh

echo "===Unlinking clusters through linkerd ==="
for cluster in "$@"
do
  for target in "$@";
  do
     if [ "$cluster" = "$target" ]; then continue; fi;
     linkerd multicluster --context=k3d-$cluster link-gen \
      --cluster-name=$target \
      | kubectl --context=k3d-$cluster delete -f -
  done
done
