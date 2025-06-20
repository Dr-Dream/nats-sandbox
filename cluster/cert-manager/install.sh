#!/bin/sh

set -e

for cluster in "$@"
do
  kube_context="kind-$cluster"
  echo "=== Installing cert-manager === "
  helm --kube-context="$kube_context" upgrade --install \
    --namespace cert-manager \
    --create-namespace \
    --version v1.17.2 \
    --set crds.enabled=true \
    --wait \
    cert-manager jetstack/cert-manager

  echo "=== Installing trust-manager === "

  helm --kube-context="$kube_context" upgrade --install \
    --namespace cert-manager \
    --create-namespace \
    --set app.trust.namespace=cert-manager \
    --wait \
    trust-manager jetstack/trust-manager
done;
