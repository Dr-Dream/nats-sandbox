#!/bin/sh

set -e

CWD=$(dirname "$0")

LINKERD_REPO=linkerd-edge

for cluster in "$@"
do
  kube_context="k3d-$cluster"
  echo "=== Installing linkerd multicluster "
  controllersJson=""
  for target in "$@";
  do
    if [ "$cluster" = "$target" ]; then continue; fi;
    if [ -n "${controllersJson}" ]; then controllersJson="$controllersJson,"; fi;
    controllersJson="$controllersJson{\"link\":{\"ref\":{\"name\":\"$target\"},\"logLevel\":\"debug\",\"enableHeadlessServices\":true}}"
  done
  helm --kube-context="$kube_context" upgrade --wait --install -n linkerd-multicluster --create-namespace \
    --set-json "controllers=[$controllersJson]" \
    --set "controllerDefaults.enableHeadlessServices=true" \
    --set "controllerDefaults.logLevel=debug" \
    --set "localServiceMirror.logLevel=debug" \
    linkerd-multicluster "$LINKERD_REPO/linkerd-multicluster"
done


