#!/bin/sh


CWD=$(dirname "$0")


"$CWD/install-cert-manager.sh" "$@"
"$CWD/install-linkerd.sh" "$@"

