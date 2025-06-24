#!/bin/sh

set -e

for cluster in "$@";
do
  k3d cluster create --agents 2 --network "linkerd-idc" --k3s-arg="--disable=traefik@server:0" "$cluster"
done;
