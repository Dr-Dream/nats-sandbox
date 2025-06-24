#!/bin/sh

set -e

CWD=$(dirname "$0")

for cluster in "$@";
do
  kube_context="k3d-$cluster"
  echo "=== Creating trust bundle ===="
#  kubectl --context="$kube_context" -n linkerd apply -f "$CWD/linkerd-ca-bundle.yaml"
  for target in "$@";
  do
    if [ "$cluster" = "$target" ]; then continue; fi;
    echo "==== Copy tls.crt $target -> $cluster ==="
    targetKindContext="k3d-$target"
    trustAnchorName="linkerd-trust-anchor-$target"
    set +e
    kubectl --context="$kube_context" -n cert-manager get secret $trustAnchorName
    anchorNotImported=$?
    set -e
    if [ $anchorNotImported -eq 0 ]; then
      echo "=== trust anchor already present ==="
      kubectl --context="$kube_context" -n cert-manager delete secret "$trustAnchorName"
    fi
    # TODO: Check exitance and then patch
    echo "=== creating trust anchor "
    kubectl --context="$kube_context" -n cert-manager create secret generic "$trustAnchorName" --from-literal=tls.crt="$(kubectl --context="$targetKindContext" -n cert-manager get secret linkerd-trust-anchor -o jsonpath='{.data.tls\.crt}' | base64 -d)"
    kubectl --context="$kube_context" -n cert-manager patch Bundle linkerd-identity-trust-roots --type='json' --patch='[{"op":"add","path":"/spec/sources/-", "value":{"secret":{"name":"'"$trustAnchorName"'","key":"tls.crt"}}}]'
  done
done
