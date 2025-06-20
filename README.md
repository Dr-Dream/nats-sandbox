# Nats Cross-Region Supercluster sandbox (k8s)

Install 3 kind clusters
### Creating clusters
```shell
for cluster in "spb1" "spb2" "sbe"; 
do
  export CLUSTER_NAME=$cluster
  envsubst < cluster/kind-cluster.yaml | kind create cluster --config -
done;
```


Adding helm repos
```shell
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add nats https://nats-io.github.io/k8s/helm/charts/ --force-update 
helm repo add linkerd-edge https://helm.linkerd.io/edge
helm repo add linkerd https://helm.linkerd.io/stable
```

### Creating clustersgit branch -M main
### Installing requirements

```shell
cluster_index=0
for cluster in "spb1" "spb2" "sbe"; 
do
  ./cluster/install-requirements.sh $cluster_index $cluster
  ((cluster_index++))
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
  helm --kube-context="kind-$cluster" -n nats uninstall xr-js
done;
```

```shell
set -e
for cluster in "spb1" "spb2" "sbe"; 
do
  kube_context="kind-$cluster"
  helm --kube-context="$kube_context" -n linkerd uninstall linkerd-viz 
  helm --kube-context="$kube_context" -n linkerd-viz upgrade --install --create-namespace \
    --set 'prometheus.enabled=false' \
    --wait \
    --set 'prometheusUrl=http://prometheus-operated.prometheus:9090' \
    linkerd-viz linkerd/linkerd-viz
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
  ./cluster/install-requirements.sh 0 spb1
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
for cluster in "spb1" "spb2" "sbe"; 
do
  kubectl config use-context kind-$cluster
  helm uninstall -n nats $cluster
done;
```
```shell
helm upgrade --install \
  -n nats --create-namespace \
  -f ./nats/jetstream.yaml \
  --set 'natsBox.enabled=false' \
  --set "config.cluster.merge.name=xr-js" \
  --set "config.cluster.replicas=1" \
  --set "config.gateway.merge.name=xr-js" \
  --set-json "config.gateway.merge.gateways=[{\"name\":\"spb1\",\"url\":\"nats://gwu:gwp@172.20.0.13:7222\"},{\"name\":\"spb2\",\"url\":\"nats://gwu:gwp@172.20.0.14:7222\"},{\"name\":\"sbe\",\"url\":\"nats://gwu:gwp@172.20.0.15:7222\"},{\"name\":\"xr-js\",\"urls\":[\"nats://gwu:gwp@172.20.0.13:7222\",\"nats://gwu:gwp@172.20.0.14:7222\",\"nats://gwu:gwp@172.20.0.15:7222\"]}]" \
  sbe-js-xr nats/nats
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
    kubectl config use-context kind-$cluster
    helm upgrade --install linkerd-crds linkerd-edge/linkerd-crds \
      -n linkerd --create-namespace --set installGatewayAPI=true
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
  kubectl config use-context kind-$cluster
  helm upgrade --install \
  trust-manager jetstack/trust-manager \
  --namespace cert-manager \
  --set app.trust.namespace=cert-manager \
  --wait
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  # This is the name of the Issuer resource; it's the way
  # Certificate resources can find this issuer.
  name: linkerd-trust-root-issuer
  namespace: cert-manager
spec:
  selfSigned: {}
EOF
done;
```
```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: linkerd-trust-anchor
  namespace: cert-manager
spec:
  issuerRef:
    kind: Issuer
    name: linkerd-trust-root-issuer
  secretName: linkerd-trust-anchor
  isCA: true
  commonName: root.linkerd.cluster.local
  duration: 8760h0m0s
  renewBefore: 7320h0m0s
  privateKey:
    rotationPolicy: Always
    algorithm: ECDSA
EOF
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl get secret -n cert-manager linkerd-trust-anchor -o yaml \
        | sed -e s/linkerd-trust-anchor/linkerd-previous-anchor/ \
        | egrep -v '^  *(resourceVersion|uid)' \
        | kubectl apply -f -
done;
```


```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  # This is the name of the Issuer resource; it's the way
  # Certificate resources can find this issuer.
  name: linkerd-identity-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: linkerd-trust-anchor
EOF
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: linkerd-identity-issuer
  namespace: linkerd
spec:
  issuerRef:
    name: linkerd-identity-issuer
    kind: ClusterIssuer
  secretName: linkerd-identity-issuer
  isCA: true
  commonName: identity.linkerd.cluster.local
  duration: 48h0m0s
  renewBefore: 25h0m0s
  privateKey:
    rotationPolicy: Always
    algorithm: ECDSA
EOF
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl apply -f - <<EOF
---
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  # This is the name of the Bundle and _also_ the name of the
  # ConfigMap in which we'll write the trust bundle.
  name: linkerd-identity-trust-roots
  namespace: linkerd
spec:
  # This tells trust-manager where to find the public keys to copy into
  # the trust bundle.
  sources:
    # This is the Secret that cert-manager will update when it rotates
    # the trust anchor.
    - secret:
        name: "linkerd-trust-anchor"
        key: "tls.crt"
    - secret:
        name: "linkerd-previous-anchor"
        key: "tls.crt"
  target:
    configMap:
      key: "ca-bundle.crt"
    namespaceSelector:
      matchLabels:
        linkerd.io/is-control-plane: "true"
EOF
done;
```




```shell
for cluster in "spb1" "spb2" "sbe"; 
do
kubectl config use-context kind-$cluster
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: linkerd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cert-manager-secret-creator
  namespace: linkerd
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-secret-creator-binding
  namespace: linkerd
subjects:
  - kind: ServiceAccount
    name: cert-manager
    namespace: linkerd
roleRef:
  kind: Role
  name: cert-manager-secret-creator
  apiGroup: rbac.authorization.k8s.io
EOF
done;
```


```shell
for cluster in "spb1" "spb2" "sbe"; 
do
    kubectl config use-context kind-$cluster
    helm upgrade --install linkerd-control-plane \
      --set identity.externalCA=true \
      --set identity.issuer.scheme=kubernetes.io/tls \
      -n linkerd \
      linkerd-edge/linkerd-control-plane
done;
```

```shell
for cluster in "spb1" "spb2" "sbe"; 
do
    kubectl config use-context kind-$cluster
    kubectl label namespace linkerd linkerd.io/is-control-plane=true
done;
```


```shell
for cluster in "spb1" "spb2" "sbe"; 
do
    kubectl config use-context kind-$cluster
    helm uninstall linkerd-multicluster -n linkerd-multicluster
    helm upgrade --install --wait -n linkerd-multicluster --create-namespace \
        --set "controllers[0].link.ref.name=$cluster" \
        --wait \
        linkerd-multicluster linkerd/linkerd-multicluster
done;
```


```shell
for cluster in "spb1" "spb2" "sbe"; 
do
    kubectl config use-context kind-$cluster
    externalControlPlaneIp=$(docker inspect $cluster-control-plane --format "{{ .NetworkSettings.Networks.kind.IPAddress }}")
    echo "$externalControlPlaneIp"
    for target in "spb1" "spb2" "sbe";
    do
       if [ "$cluster" = "$target" ]; then continue; fi;
       echo "$cluster ($externalControlPlaneIp) => $target";
       linkerd multicluster --context=kind-$cluster link \
        --cluster-name=$cluster \
        --verbose \
        --api-server-address="https://$externalControlPlaneIp:6443" \
        | kubectl --context=kind-$target apply -f -
    done;
done;

```
