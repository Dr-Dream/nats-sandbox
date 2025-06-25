#!/bin/sh

set -e

for cluster in "$@";
do
  k3d cluster stop "$cluster"
done;
