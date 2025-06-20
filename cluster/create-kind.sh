#!/bin/sh

set -e

CWD=$(dirname "$0")

for cluster in "spb1" "spb2" "sbe";
do
  export CLUSTER_NAME=$cluster
  envsubst < "$CWD/kind-cluster.yaml" | kind create cluster --config -
done;
