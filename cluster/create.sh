#!/bin/sh

set -e

for cluster in "$@";
do
  k3d cluster create --agents 2 "$cluster"
done;
