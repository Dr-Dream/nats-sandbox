#!/bin/sh

set -e

CWD=$(dirname "$0")

LINKERD_REPO=linkerd-edge

for cluster in "$@"
do
  kube_context="kind-$cluster"
  echo "=== Installing linkerd multicluster "
  controllersJson=""
  for target in "$@";
  do
    if [ "$cluster" = "$target" ]; then continue; fi;
    if [ -n "${controllersJson}" ]; then controllersJson="$controllersJson,"; fi;
    controllersJson="$controllersJson{\"link\":{\"ref\":{\"name\":\"$target\"},\"logLevel\":\"debug\",\"enableHeadlessServices\":true}}"
  done

#    --set "controllers[0].link.ref.name=spb1" \
#    --set "controllers[0].link.logLevel=debug" \
#    --set "controllers[0].link.enableHeadlessServices=true" \
#    --set "controllers[1].link.ref.name=spb2" \
#    --set "controllers[1].link.logLevel=debug" \
#    --set "controllers[1].link.enableHeadlessServices=true" \
#    --set "controllers[2].link.ref.name=sbe" \
#    --set "controllers[2].link.logLevel=debug" \
#    --set "controllers[2].link.enableHeadlessServices=true" \
  echo $controllersJson


  helm --kube-context="$kube_context" upgrade --wait --install -n linkerd-multicluster --create-namespace \
    --set-json "controllers=[$controllersJson]" \
    --set "controllerDefaults.enableHeadlessServices=true" \
    --set "controllerDefaults.logLevel=debug" \
    --set "localServiceMirror.logLevel=debug" \
    linkerd-multicluster "$LINKERD_REPO/linkerd-multicluster"
done


