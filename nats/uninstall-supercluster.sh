#!/bin/sh


for cluster in "$@"
do
    kube_context="kind-$cluster"
    kubectl --context="$kube_context" delete namespace nats
done
