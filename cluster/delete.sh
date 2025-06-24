#!/bin/sh

set -e

for cluster in "$@";
do
  k3d cluster delete "$cluster"
done;
