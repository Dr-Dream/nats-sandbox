#!/bin/sh

set -e

CWD=$(dirname "$0")

for cluster in "$@"
do
  kube_context="k3d-$cluster"
  echo "========== $cluster ========="
  if ! kubectl --context="$kube_context" get ns linkerd; then
    echo "== Creating namespace"
    kubectl --context="$kube_context" create namespace linkerd
  fi
  kubectl --context="$kube_context" label namespace linkerd linkerd.io/is-control-plane=true

  echo "=== Creating linkerd cert-manager Service Account ==="
  kubectl --context="$kube_context" -n linkerd apply -f $CWD/linkerd-rb-sa.yaml
  echo "=== INSTALLING ROOT CA in $cluster ==="
  kubectl --context="$kube_context" -n cert-manager apply -f $CWD/linkerd-root-ca.yaml
  echo "=== Waiting root certificate issued ==="
  kubectl --context="$kube_context" -n cert-manager wait Certificate linkerd-trust-anchor --for=condition=ready --timeout=30s
  echo "=== Waiting root certificate secret ==="
  kubectl --context="$kube_context" -n cert-manager wait secret/linkerd-trust-anchor --for=create --timeout=30s
  echo "=== Copy trust anchor to previous trust anchor (one time) $kube_context"
  set +e
  kubectl --context="$kube_context" get secret -n cert-manager linkerd-previous-anchor
  previousNotExists=$?
  set -e
  if [ $previousNotExists -ne 0 ]; then
    kubectl --context="$kube_context" get secret -n cert-manager linkerd-trust-anchor -o yaml \
            | sed -e s/linkerd-trust-anchor/linkerd-previous-anchor/ \
            | egrep -v '^  *(resourceVersion|uid)' \
            | kubectl --context="$kube_context" apply -f -
  fi
  echo "=== Creating trust bundle ==="
  kubectl --context="$kube_context" -n cert-manager apply -f "$CWD/linkerd-ca-bundle.yaml"
  echo "=== Installing identity issuer ===="
  kubectl --context="$kube_context" -n linkerd apply -f $CWD/linkerd-identity-issuer.yaml
  echo "=== Waiting identity issuer certificate ==="
  kubectl --context="$kube_context" -n linkerd wait Certificate linkerd-identity-issuer --for=condition=ready --timeout=30s
  echo "=== Waiting identity issuer certificate secret ==="
  kubectl --context="$kube_context" -n linkerd wait secret/linkerd-identity-issuer --for=create --timeout=30s
done
