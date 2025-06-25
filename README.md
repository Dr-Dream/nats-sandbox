# Nats Cross-Region Supercluster sandbox (k8s)

## DISCLAIMER
> THIS REPO IS DONE JUST FOR FUN TO EASE SETUP MULTICLUSTER NATS ENVIRONMENT.
> I STRONGLY **NOT** RECOMMEND TO USE ANY OF THIS SCRIPTS AND/OR CONFIGURATIONS IN PRODUCTION DUE PERFORMANCE AND SECURITY ISSUES.
> THIS SCRIPTS AND RESULTS OF IT WORK IS ONLY FOR EDUCATIONAL PURPOSES.
> BEFORE RUNNING SCRIPTS BE SURE YOU UNDERSTAND WHAT YOU ARE DOING.


## Idea

The goal of this repo is to have some easy utils to install locally multicluster environment
to play with NATs Superclusters and Stretched JetStream clusters. Also to play with different type of
NATs servers.

How what we actually want to do and what tools will be used for this.
* Two or more (three the best choice) Kubernetes clusters. We will use K3D for this.
* Grafana/Prometheus for monitoring. It will be kube-prometheus-stack to ease setup.
* Ingress for NATs gateways. Vanilla nginx ingress controller for k8s.
* Multicluster service mesh. Supposed to be required for Stretched NATs Cluster. Linkerd/Linkerd Multicluster.

#### Overall overview
More ore less planned deployment will look like this.
![Overall diagram](./docs/images/Overall.drawio.svg)

Let's dive in details.
##### 3 k8s clusters. 
K3D helps. (K8S Cluster C1,C2,C3 on diagram)
#### Nats regional clusters and Super Cluster
In terms of nats we want to have 1 nats cluster which will contain following nodes:
* 3 Core Nats servers as seed nodes for cluster (nats). This core NATS servers with simple pub/sub functionality. Also mentioned in documentation as computing nodes.
* 3 JetStream enabled (nats-js). In terms of NATS this is nodes that manges Streams/KV Stores/Object Stores. Actually it is cluster wide storage (file or memory) providers.
* 3 Core Nats for gateways (nats-gw). Actually same as nats, but only them will be used as gateways. Just for traffic isolation. So gateways used for forming super cluster. 

To make cluster all nodes should be strongly connected. All should be able will talk to each other and exchange 
information about other nodes. Its done by each server configuration. More info in [Clustering](https://docs.nats.io/running-a-nats-service/configuration/clustering) docs.

So in one K8S cluster we will form one Regional Cluster. Finally it will have 9 nodes. 3 computing 3 storage an 3 gateways.

Gateways will expose port 7222 (nats gateway) in ingress as TCP (not http service). Also in all NATS servers we will sign public adressess of ingresses of other clusters.
Doing this we will make possible all local nodes to talk to the nodes in other clusters. So all nodes in all clusters 
will have information about all other nodes and routes how to reach them.

That what is called Super Cluster in terms of NATS.
More information about gateways and clusters you can find in [official documentation](https://docs.nats.io/running-a-nats-service/configuration/gateways)

#### NATS JetStream/Stretched Cluster
Why we need JetStream? What is it?
Actually if we take Core NATS Pub/Sub functionality it works superfast and right in time. You pub message an consumer on 
other side get it as soon it was published. Problem is that if you publish something, but nobody listening (subscribed) 
Core NATS just drop this message. You can detect this situation on publisher side, but anyway.
Other words publisher and subscriber is time coupled. Both of them shold be connected to the system at same time.
To solve this problem yo should have layer of persistence. Where you store message until it will be consumed.

JetStream (storage enabled) Nats clusters are little bit aside of core nats. It looks like PUB/SUB but in NATS 
documentation it often called Produce/Consume. You can produce and consume whenever you want.

As soon we talk about storing and reading (persisting) data it is all about consistency.
Here is a good [article on synadia](https://www.synadia.com/blog/multi-cluster-consistency-models) (Synadia = NATS Cloud)
about consistency in nats.

There are some points about JetStream and how it works. When you create some stream it is scoped by the single NATS 
cluster. Even if you create a Super Cluster (cluster of cluster) stream data and all replicas will be located in one 
NATS cluster.

So, let's just deploy new cluster with nodes in each K8S Cluster. They will be located in other Kubernetes Cluster, but 
will be part of single NATS CLuster.

Thats why we deploy 9 nodes called xr-js (c1,c2,c3) on scheme, three in each cluster.

As soon it is a single cluster they all should be strongly connected (each to each).
To make them available for stream creation we also connect them to Regional Cluster through gateways.

One thing about xr-js cluster is that we don't plan to have dedicated nodes for computing, storage and gateways 
(i'm too lazy for this), but make all of them having all three roles (Core,JetStream,Gateway).

#### Interconnection between clusters.
There are three main aspects of clusters interconnection.
1) All nodes talks to the other clusters gateways through Ingress.
2) xr-js talks to each other through linkerd multicluster gateways.
3) xr-js nodes talks to Regional clusters through local NATS gateway services. (as soon nodes present in each cluster)

Why so?
Technically in this stand it will be same network, so no actual reason.

Logically - yes. I just want to highlight point that xr-js nats traffic much more sensitive to RTT and Network Address translation then gateway.
Traffic between members of single nats traffic much more intensive.

So we suppose that GW interconnection is behind NAT and LoadBalancer, and more latent. (Blue network on scheme)
XR-JS traffic comes from durable low latent cluster interconnection. (Green network on scheme)
(discussible, but for now i just say so :))

Let's start from the beginning.

### System requirements.
Actually its a just simple testing stand so you don't need Big server platforms to run. Moreover, i really don't
recommend to run any havy lifting on it (heavy load-tests and benchmarks).
Beside this so there is no requests and limits defined on most of pods just to run on anything that could start it.
At time of writing this doc stand takes in **idle** it takes around **4 vCPU and 12Gi of RAM without any load**. Be
aware that in case of nats bench and etc you will need much more resources (at least CPU).

### Software requirements.
At least we have an Linux/Mac machine with sh/zsh on board. Good start, but we also will require.
* [Docker](https://docs.docker.com/engine/install/). Engine and CLI. [docker-desktop](https://www.docker.com/products/docker-desktop/) is enough.
* [K3D](https://k3d.io/stable/).
* [Kubectl](https://kubernetes.io/docs/tasks/tools/).
* [Helm](https://helm.sh/docs/intro/install/).
* [Linkerd](https://linkerd.io/2.18/getting-started/).
* [Nats CLI](https://github.com/nats-io/natscli). To play with Super Cluster from host machine.

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
## Installing clusters
If you don't want to dive deeply what happening you should just run
```shell
./cluster/install.sh c1 c2 c3
```
At the end 
And skip it to [Installation of NATS](#nats_install)

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

> **_NOTE:_**  Check Expiry dates on certs and issues.
> Root: [./cluster/linkerd/linkerd-root-ca.yaml](./cluster/linkerd/linkerd-root-ca.yaml)
> Identity: [./cluster/linkerd/linkerd-identity-issuer.yaml](./cluster/linkerd/linkerd-identity-issuer.yaml)
> After their expiration they will be reissued and you need to exchange keys once more.


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

### SOME NOTE ABOUT IPs.
Sadly but in most cases we rely on LoadBalancer services with dynamic IP. Which actually could change so we refer nodes
DNS names instead of IP. k3d-[cluster name]-server-0 for linkerd gateways and k3d-[cluster name]-agent-0 for nats 
ingress connections (gateways 7222).
It is not mandatory due fact that all LoadBalancer services exposed on all nodes. This just FYI.

### VERY IMPORTANT NOTE!
In terms of resource consumption k3d not starting clusters with large number of pods (our case actually). So to start
clusters we could use helper script.
```shell
./cluster/start.sh c1 c2 c3
```

### <a name="nats_install"></a> Finally we back to nats
What will be installed. At each k8s cluster we will install NTS cluster with
* Core NATS Seed Nodes (nats)
* JetStream Enabled Nodes (nats-js)
* Gateway nodes that will be exposed through ingress to create a Nats Super Cluster (nats-gw)
* Cross-Region 'stretched' JetStream enabled nodes with in each cluster and interconnected
  through linkerd multicluster mesh. (xr-js)

So we will have a cluster in each Kubernetes cluster (let's call it datacenter). Nats clusters will be 'c1' 'c2' 'c3'
and 'xr-js'.

Clusters will contain three nodes of each type (nats, nats-js and nats-gw) so nine nodes in each. Beside this we will
have three nodes for xr-js cluster in each datacenter (nine xr-js nodes).

All clusters will be interconnected in NATS SuperCluster, so it will be 36 nodes SuperCluster with 18 nodes for JetStream.

```shell
./nats/install-supercluster.sh c1 c2 c3
```

### Setting up local cli
We deployed cluster with two predefined accounts SYS: 
* SYS (username=sys, password=sys) is a system operator. Other words super root for nats.
* JS (username=js, password=js) is stream enabled operator (it can't be sys).

#### Connectivity
First of all we need to have connection to any servers that located in clusters. Fortunately, we already exposed 4222 
port through haproxy ingress pointing to Seed cluster. So we just need to expose this ports to host.
As soon we have Super Cluster we don't care which cluster we will be connected. Let it be c1
```shell
k3d cluster edit c1 --port-add "4222:4222@loadbalancer"
```
More info you can find in [K3D expose docs](https://k3d.io/stable/usage/exposing_services/).

#### Nats contexts
Lets add contexts to nats cli.
```shell
nats context add --user sys --password sys --description "NATS Seed C1 SYS" --server nats://localhost:4222 c1
```
```shell
nats context add --user js --password js --description "NATS Seed C1 JS" --server nats://localhost:4222 c1-js
```


After that, select account you want to play with.
```shell
nats context select c1
```
> **_NOTE:_**  Be sure you are using right context SYS account don't have any JetStream permissions 
> (any nats stream command will fail). At same time JS account don't have any permissions to manage servers or clusters.

List servers:
```shell
nats server list --sort=name
```

Running nats client supposed to be something like this:
```
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
## Clean UP
Just delete K3D clusters. :)
```shell
./cluster/delete.sh c1 c2 c3
```
## TODO:
- [ ] Websockets and Leafnodes?
- [ ] JWT Authentication
- [ ] KV Tests
- [ ] Strong consistency Cross-Region Stream example
- [ ] Eventual consistency Cross-Region example
- [ ] Handle host and cluster restarts 
- [ ] Accessing Grafana
