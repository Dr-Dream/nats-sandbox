
Install 3 kind clusters
SPB 1
```shell
kind create cluster --config kind-clusters/spb1.yaml 
```
SPB 2
```shell
kind create cluster --config kind-clusters/spb2.yaml 
```
SBE
```shell
kind create cluster --config kind-clusters/sbe.yaml 
```

Adding helm repos
```shell
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add nats https://nats-io.github.io/k8s/helm/charts/ --force-update 
```
### Creating clusters
```shell
for cluster in "spb1" "spb2" "sbe"; 
do
  export CLUSTER_NAME=$cluster
  envsubst < kind-clusters/kind-cluster.yaml | kind create cluster --config -
done;
```

### Creating clustersgit branch -M main
### Installing requirements

```shell
cluster_index=0
for cluster in "spb1" "spb2" "sbe"; 
do
  ./kind-clusters/install-requirements.sh $cluster_index $cluster
  ((cluster_index++))
done;
```

### Deleting clusters
```shell
for cluster in "spb1" "spb2" "sbe"; 
do
  kind delete clusters $cluster
done;
```

```shell
  ./kind-clusters/install-requirements.sh 0 spb1
```

```shell
#  --set "config.websocket.ingress.hosts={spb1.local}" \

kubectl config use-context kind-spb1
helm upgrade --install \
  -n nats --create-namespace \
  -f ./nats/cluster.yaml \
  --set 'config.cluster.merge.name=nats' \
  --set 'natsBox.enabled=true' \
  nats nats/nats
```

```shell
#  --set "config.websocket.ingress.hosts={spb1.local}" \ 
#  --set 'config.cluster.merge.routes={nats://nats:6222,nats://nats-1.nats-headless:6222,nats://nats-2.nats-headless:6222,nats://nats-0.jetstream-nats-headless:6222,nats://nats-1.jetstream-nats-headless:6222,nats://nats-2.jetstream-nats-headless:6222}' \ 
#  --set 'config.cluster.merge.routes={nats://nats-0.nats-headless:6222,nats://nats-1.nats-headless:6222,nats://nats-2.nats-headless:6222,nats://jetstream-nats-0.jetstream-nats-headless:6222,nats://jetstream-nats-1.jetstream-nats-headless:6222,nats://jetstream-nats-2.jetstream-nats-headless:6222}' \ 
#  --set 'config.cluster.merge.routes={nats://nats:6222,nats://jetstream-nats:6222' \ 
#  --set 'config.cluster.merge.routes={nats://jetstream-nats-0.jetstream-nats-headless:6222,nats://jetstream-nats-1.jetstream-nats-headless:6222,nats://jetstream-nats-2.jetstream-nats-headless:6222,nats://nats-0.nats-headless:6222,nats://nats-1.nats-headless:6222,nats://nats-2.nats-headless:6222}' \ 
#  --set 'config.cluster.merge.routes={nats://jetstream-nats-0.jetstream-nats-headless:6222,nats://jetstream-nats-1.jetstream-nats-headless:6222,nats://jetstream-nats-2.jetstream-nats-headless:6222,nats://nats-0.nats-headless:6222,nats://nats-1.nats-headless:6222,nats://nats-2.nats-headless:6222}' \ 

echo 1

kubectl config use-context kind-spb1
helm upgrade --install \
  -n nats --create-namespace \
  -f ./nats/jetstream.yaml \
  --set 'config.cluster.merge.name=nats' \
  --set 'natsBox.enabled=false' \
  --set 'config.cluster.merge.routes={nats://jetstream-nats-0.jetstream-nats-headless:6222,nats://jetstream-nats-1.jetstream-nats-headless:6222,nats://jetstream-nats-2.jetstream-nats-headless:6222,nats://nats:6222}' \
  jetstream nats/nats
```

```shell
kubectl config use-context kind-sbe
helm upgrade --install --dry-run \
  -n nats --create-namespace \
  -f ./nats/gateway.yaml \
  --set "config.cluster.merge.name=sbe" \
  --set 'natsBox.enabled=false' \
  --set "config.cluster.merge.routes={nats://sbe-gw-nats-0.sbe-gw-nats-headless:6222,nats://sbe-gw-nats-1.sbe-gw-nats-headless:6222,nats://sbe-gw-nats-2.sbe-gw-nats-headless:6222,nats://sbe-nats:6222}" \
  --set "config.gateway.merge.name=sbe" \
  --set-json "config.gateway.merge.gateways=[{\"name\":\"spb1\",\"url\":\"nats://172.20.0.10:7222\"},{\"name\":\"spb2\",\"url\":\"nats://172.20.0.11:7222\"},{\"name\":\"sbe\",\"url\":\"nats://172.20.0.13:7222\"}]" \
  "$cluster-gw" nats/nats
```




```shell
helm uninstall -n nats sbe-gw
```

nats://jetstream-nats-0.jetstream-nats-headless:6222,nats://jetstream-nats-1.jetstream-nats-headless:6222,nats://jetstream-nats-2.jetstream-nats-headless:6222
```shell
kubectl config use-context kind-spb2
helm uninstall -n nats spb2-gw 
```
