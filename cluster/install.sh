#!/bin/sh

set -e

CWD=$(dirname "$0")

# Creating clusters
$CWD/create.sh "$@"
# Crert/Trust managers
$CWD/cert-manager/install.sh "$@"
# Linkerd PKI
$CWD/linkerd/init.sh "$@"
# Linkerd MC trust
$CWD/linkerd-multicluster/key-exchange.sh "$@"
# Linkerd install
$CWD/linkerd/install.sh "$@"
# Linkerd MC install
$CWD/linkerd-multicluster/install.sh "$@"
# Linkerd MC link
$CWD/linkerd-multicluster/link.sh "$@"
# Prometheus/Grafana
$CWD/grafana/install.sh "$@"
# Linkerd viz
$CWD/linkerd-viz/install.sh "$@"
# Haproxy ingress
$CWD/haproxy-ingress/install.sh "$@"

