#!/bin/sh


for cluster in "$@"
do
    kube_context="k3d-$cluster"
    kubectl --context="$kube_context" delete namespace nats
done
