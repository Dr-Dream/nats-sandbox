# Nats Cross-Region Supercluster sandbox (k8s)

## DISCLAIMER
> THIS REPO IS DONE JUST FOR FUN TO EASE SETUP MULTICLUSTER NATS ENVIRONMENT.
> I STRONGLY **NOT** RECOMMEND TO USE ANY OF THIS SCRIPTS AND/OR CONFIGURATIONS IN PRODUCTION DUE PERFORMANCE AND SECURITY ISSUES.
> THIS SCRIPTS AND RESULTS OF IT WORK IS ONLY FOR EDUCATIONAL PURPOSES.
> BEFORE RUNNING SCRIPTS BE SURE YOU UNDERSTAND WHAT YOU ARE DOING.


## Overview

The goal of this repo is to have some easy utils to install locally multicluster environment
to play with NATs Superclusters and Stretched JetStream clusters. Also to play with different type of
NATs servers.

How what we actually want to do and what tools will be used for this.
* Two or more (three the best choice) Kubernetes clusters. We will use K3D for this.
* Grafana/Prometheus for monitoring. It will be kube-prometheus-stack to ease setup.
* Ingress for NATs gateways. Vanilla nginx ingress controller for k8s.
* Multicluster service mesh. Supposed to be required for Stretched NATs Cluster. Linkerd/Linkerd Multicluster.

#### TODO: Overall diagram

Let's start from the beginning.

### Local machine requirements
At least we have an Linux/Mac machine with sh/zsh on board. Good start, but we also will require.
* [Docker](https://docs.docker.com/engine/install/). Engine and CLI. [docker-desktop](https://www.docker.com/products/docker-desktop/) is enough.
* [K3D](https://k3d.io/stable/).
* [Kubectl](https://kubernetes.io/docs/tasks/tools/).
* [Helm](https://helm.sh/docs/intro/install/).
* [Linkerd](https://linkerd.io/2.18/getting-started/).

> **_NOTE:_** Actually all of them are available in public repos with almost all package managers (yum, apt, homebrew etc...)

After helm installation also we need to add some useful repos.
```shell
# Cert/Trust manager
helm repo add jetstack https://charts.jetstack.io --force-update
# Haproxy Ingress Controller
helm repo add haproxytech https://haproxytech.github.io/helm-charts
# Grafana/Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
# Linkerd
helm repo add linkerd-edge https://helm.linkerd.io/edge
helm repo add linkerd https://helm.linkerd.io/stable
# NATs helm charts
helm repo add nats https://nats-io.github.io/k8s/helm/charts/ --force-update 
```


### Creating a clusters.
So let's create our k8s clusters. It will be one node for control-plane (called server in k3d) and two workers
(called agents).
```shell
./cluster/create.sh c1 c2 c3
```
By the end of script you will have three clusters ready to use.
* c1 (kubectl context will be 'k3d-c1')
* c2 (kubectl context will be 'k3d-c2')
* c3 (kubectl context will be 'k3d-c3')

You can use whatever naming you want but remember those cluster names (c1,c2,c3), they will be
used in later stages to identify clusters inside scripts and should be passed same way to other scripts.

All nodes will be connected to internal clusters (depending on their membership) with flannel cni (k3d default).
But also all nodes connected to single docker network called "linkerd-idc" for clusters interconnection.

You can check [./create.sh](./cluster/create.sh).

> **_NOTE:_**  Traefik Ingress controller disabled by script, as soon as we will be using haproxy instead.

### Load balancer
We have clusters and planning to interact with services inside clusters,
we will need something that will expose it for us. At least we want to reach ingress controllers.
Fortunately, k3d have load balancer out of the box. So all LoadBalancer services balanced on each node of the cluster.

For each cluster, we also have special container to expose LoadBalancer services to the host which is called
'k3d-[cluster name]-serverlb'.

It will expose all services with type LoadBalancer to host machine.
It is quite easy to manage. Take a look at [docs](https://k3d.io/stable/usage/exposing_services/).

### Cert/Trust Managers
It is required for Mesh (linkerd). Actually not everywhere, you can use your own PKI, but it will simplify a lot of
things in our setup.
```shell
./cluster/cert-manager/install.sh c1 c2 c3
```
It is a simple helm install. Check [./cluster/cert-manager/install.sh](./cluster/cert-manager/install.sh)

### Let's mesh it
#### PKI
At least we need trust anchors for linkerd in each cluster, also identity certificate issuer for meshing and
authorization at services level. If you need something special, then you should check
[Linkerd Installation Docs](https://linkerd.io/2-edge/tasks/install-helm/).

In our case we will use simple self-signed certs managed by cert manager.
Following script will do all dirty work for you.
```shell
./cluster/linkerd/init.sh c1 c2 c3
```
Check [./cluster/linkerd/init.sh](./cluster/linkerd/init.sh) for more details.


Next point is that we plan to have not only cluster level mesh but also multicluster mesh. So we need to exchange trust
chains between clusters (as soon each cluster manages its own trust chain).
```shell
./cluster/linkerd-multicluster/key-exchange.sh c1 c2 c3
```
Check [./cluster/linkerd-multicluster/key-exchange.sh](./cluster/linkerd-multicluster/key-exchange.sh) for more details.

#### Install linkerd
[./cluster/linkerd/install.sh](./cluster/linkerd/install.sh)
```shell
./cluster/linkerd/install.sh c1 c2 c3
```
[./cluster/linkerd-multicluster/install.sh](./cluster/linkerd-multicluster/install.sh)
```shell
./cluster/linkerd-multicluster/install.sh c1 c2 c3
```
#### Link clusters
[./cluster/linkerd-multicluster/link.sh](./cluster/linkerd-multicluster/link.sh)
```shell
./cluster/linkerd-multicluster/link.sh c1 c2 c3
```

### Some observability stuff
#### Grafana/Prometheus Stack
Quite simple helm install.
```shell
./cluster/grafana/install.sh c1 c2 c3
```
Check [./cluster/grafana/install.sh](./cluster/grafana/install.sh)
#### Linkerd-viz
Just a simple linkerd dashboard on same prometheus instance. Also some linkerd pod/service monitors.
```shell
./cluster/linkerd-viz/install.sh c1 c2 c3 
```

### Ingress
```shell
./cluster/haproxy-ingress/install.sh c1 c2 c3
```

### Finally we back to nats
What will be installed. At each k8s cluster we will install NTS cluster with
* Core NATS Seed Nodes (nats)
* Jetstream Enabled Nodes (nats-js)
* Gateway nodes that will be exposed through ingress to create a Nats Super Cluster (nats-gw)
* Cross-Region 'stretched' Jetstream enabled cluster with in each cluster and interconnected
  through linkerd multicluster mesh. (xr-js)

So we will have a cluster in each Kubernetes cluster (let's call it datacenter). Nats clusters will be 'c1' 'c2' 'c3'
and 'xr-js'.

Clusters will contain three nodes of each type (nats, nats-js and nats-gw) so nine nodes in each. Beside this we will
have three nodes for xr-js cluster in each datacenter (nine xr-js nodes).

All clusters will be interconnected in NATS SuperCluster so it will be 36 nodes SuperCluster with 18 nodes for JetStream.

```shell
./nats/install-supercluster.sh c1 c2 c3
```

Running nats client supposed to be something like this:
```shell
╭───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                                          Server Overview                                                          │
├─────────────────┬─────────┬──────┬─────────┬─────┬───────┬────────┬────────┬─────┬─────────┬───────┬───────┬──────┬────────┬──────┤
│ Name            │ Cluster │ Host │ Version │ JS  │ Conns │ Subs   │ Routes │ GWs │ Mem     │ CPU % │ Cores │ Slow │ Uptime │ RTT  │
├─────────────────┼─────────┼──────┼─────────┼─────┼───────┼────────┼────────┼─────┼─────────┼───────┼───────┼──────┼────────┼──────┤
│ c1-gw-nats-0    │ c1      │ 0    │ 2.11.4  │ no  │ 0     │ 516    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 5m1s   │ 3ms  │
│ c1-gw-nats-1    │ c1      │ 0    │ 2.11.4  │ no  │ 0     │ 516    │     32 │   3 │ 16 MiB  │ 4     │    14 │ 0    │ 5m6s   │ 6ms  │
│ c1-gw-nats-2    │ c1      │ 0    │ 2.11.4  │ no  │ 0     │ 516    │     32 │   3 │ 17 MiB  │ 0     │    14 │ 0    │ 4m32s  │ 3ms  │
│ c1-js-nats-0    │ c1      │ 0    │ 2.11.4  │ yes │ 0     │ 517    │     32 │   3 │ 16 MiB  │ 12    │    14 │ 0    │ 4m58s  │ 5ms  │
│ c1-js-nats-1    │ c1      │ 0    │ 2.11.4  │ yes │ 0     │ 517    │     32 │   3 │ 17 MiB  │ 0     │    14 │ 0    │ 4m48s  │ 3ms  │
│ c1-js-nats-2    │ c1      │ 0    │ 2.11.4  │ yes │ 0     │ 517    │     32 │   3 │ 17 MiB  │ 1     │    14 │ 0    │ 4m58s  │ 3ms  │
│ c1-nats-0       │ c1      │ 0    │ 2.11.4  │ no  │ 0     │ 516    │     32 │   3 │ 15 MiB  │ 0     │    14 │ 0    │ 5m1s   │ 3ms  │
│ c1-nats-1       │ c1      │ 0    │ 2.11.4  │ no  │ 1     │ 516    │     32 │   3 │ 16 MiB  │ 1     │    14 │ 0    │ 5m6s   │ 3ms  │
│ c1-nats-2       │ c1      │ 0    │ 2.11.4  │ no  │ 0     │ 516    │     32 │   3 │ 15 MiB  │ 0     │    14 │ 0    │ 5m0s   │ 3ms  │
│ c1-xr-js-nats-0 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 16 MiB  │ 7     │    14 │ 0    │ 4m44s  │ 9ms  │
│ c1-xr-js-nats-1 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 16 MiB  │ 8     │    14 │ 0    │ 4m59s  │ 8ms  │
│ c1-xr-js-nats-2 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 16 MiB  │ 9     │    14 │ 0    │ 4m57s  │ 7ms  │
│ c2-gw-nats-0    │ c2      │ 0    │ 2.11.4  │ no  │ 0     │ 524    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 4m31s  │ 6ms  │
│ c2-gw-nats-1    │ c2      │ 0    │ 2.11.4  │ no  │ 0     │ 524    │     32 │   3 │ 15 MiB  │ 5     │    14 │ 0    │ 4m58s  │ 10ms │
│ c2-gw-nats-2    │ c2      │ 0    │ 2.11.4  │ no  │ 0     │ 524    │     32 │   3 │ 15 MiB  │ 0     │    14 │ 0    │ 4m21s  │ 5ms  │
│ c2-js-nats-0    │ c2      │ 0    │ 2.11.4  │ yes │ 0     │ 525    │     32 │   3 │ 16 MiB  │ 2     │    14 │ 0    │ 4m30s  │ 6ms  │
│ c2-js-nats-1    │ c2      │ 0    │ 2.11.4  │ yes │ 0     │ 525    │     32 │   3 │ 15 MiB  │ 7     │    14 │ 0    │ 4m21s  │ 8ms  │
│ c2-js-nats-2    │ c2      │ 0    │ 2.11.4  │ yes │ 0     │ 525    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 4m25s  │ 6ms  │
│ c2-nats-0       │ c2      │ 0    │ 2.11.4  │ no  │ 0     │ 524    │     32 │   3 │ 15 MiB  │ 0     │    14 │ 0    │ 4m59s  │ 7ms  │
│ c2-nats-1       │ c2      │ 0    │ 2.11.4  │ no  │ 0     │ 524    │     32 │   3 │ 15 MiB  │ 1     │    14 │ 0    │ 4m58s  │ 8ms  │
│ c2-nats-2       │ c2      │ 0    │ 2.11.4  │ no  │ 0     │ 524    │     32 │   3 │ 14 MiB  │ 0     │    14 │ 0    │ 4m21s  │ 6ms  │
│ c2-xr-js-nats-0 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 15 MiB  │ 8     │    14 │ 0    │ 4m25s  │ 10ms │
│ c2-xr-js-nats-1 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 15 MiB  │ 6     │    14 │ 0    │ 4m30s  │ 8ms  │
│ c2-xr-js-nats-2 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 15 MiB  │ 5     │    14 │ 0    │ 4m21s  │ 7ms  │
│ c3-gw-nats-0    │ c3      │ 0    │ 2.11.4  │ no  │ 0     │ 515    │     32 │   3 │ 17 MiB  │ 0     │    14 │ 0    │ 4m32s  │ 7ms  │
│ c3-gw-nats-1    │ c3      │ 0    │ 2.11.4  │ no  │ 0     │ 515    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 4m54s  │ 9ms  │
│ c3-gw-nats-2    │ c3      │ 0    │ 2.11.4  │ no  │ 0     │ 515    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 4m45s  │ 9ms  │
│ c3-js-nats-0    │ c3      │ 0    │ 2.11.4  │ yes │ 0     │ 516    │     32 │   3 │ 18 MiB  │ 1     │    14 │ 0    │ 4m32s  │ 7ms  │
│ c3-js-nats-1    │ c3      │ 0    │ 2.11.4  │ yes │ 0     │ 516    │     32 │   3 │ 18 MiB  │ 1     │    14 │ 0    │ 4m28s  │ 7ms  │
│ c3-js-nats-2    │ c3      │ 0    │ 2.11.4  │ yes │ 0     │ 516    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 4m19s  │ 7ms  │
│ c3-nats-0       │ c3      │ 0    │ 2.11.4  │ no  │ 0     │ 515    │     32 │   3 │ 14 MiB  │ 0     │    14 │ 0    │ 4m32s  │ 8ms  │
│ c3-nats-1       │ c3      │ 0    │ 2.11.4  │ no  │ 0     │ 515    │     32 │   3 │ 14 MiB  │ 0     │    14 │ 0    │ 4m54s  │ 7ms  │
│ c3-nats-2       │ c3      │ 0    │ 2.11.4  │ no  │ 0     │ 515    │     32 │   3 │ 14 MiB  │ 4     │    14 │ 0    │ 4m17s  │ 6ms  │
│ c3-xr-js-nats-0 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 16 MiB  │ 5     │    14 │ 0    │ 4m27s  │ 7ms  │
│ c3-xr-js-nats-1 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 16 MiB  │ 2     │    14 │ 0    │ 4m24s  │ 7ms  │
│ c3-xr-js-nats-2 │ xr-js   │ 0    │ 2.11.4  │ yes │ 0     │ 552    │     32 │   3 │ 18 MiB  │ 0     │    14 │ 0    │ 4m20s  │ 6ms  │
├─────────────────┼─────────┼──────┼─────────┼─────┼───────┼────────┼────────┼─────┼─────────┼───────┼───────┼──────┼────────┼──────┤
│                 │ 4       │ 36   │         │ 18  │ 1     │ 18,972 │        │     │ 579 MiB │       │       │ 0    │        │      │
╰─────────────────┴─────────┴──────┴─────────┴─────┴───────┴────────┴────────┴─────┴─────────┴───────┴───────┴──────┴────────┴──────╯

╭────────────────────────────────────────────────────────────────────────────╮
│                              Cluster Overview                              │
├─────────┬────────────┬───────────────────┬───────────────────┬─────────────┤
│ Cluster │ Node Count │ Outgoing Gateways │ Incoming Gateways │ Connections │
├─────────┼────────────┼───────────────────┼───────────────────┼─────────────┤
│ c3      │          9 │                27 │                27 │           0 │
│ c2      │          9 │                27 │                27 │           0 │
│ xr-js   │          9 │                27 │                27 │           0 │
│ c1      │          9 │                27 │                27 │           1 │
├─────────┼────────────┼───────────────────┼───────────────────┼─────────────┤
│         │         36 │               108 │               108 │           1 │
╰─────────┴────────────┴───────────────────┴───────────────────┴─────────────╯

```
