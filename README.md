## KIND local environment

<img src="./KIND-diagram.png?raw=true" width="800">

KIND Source: https://github.com/kubernetes-sigs/kind (https://github.com/kubernetes-sigs/kind/tree/main/images/base)

### Install KIND 
```
### Install docker, kubectl, etc.

### Instal KIND 

$ curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind (Note: k8s v1.25.3)
```
$ cd KIND/
###Create k8s Cluster and get credentials
$ kind create cluster --name gitops --config cluster-config.yaml
$ kind get kubeconfig --name="gitops" > admin.conf
$ export KUBECONFIG=./admin.conf 
### Install Calico -> REF: https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart#install-calico
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml
### Install Nginx Ingress
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```
### Clean environment

```
$ kind delete cluster --name=gitops

$ kind delete cluster --name=gitops
Deleting cluster "devsecops" ...
[1]+  Killed                  linkerd viz dashboard
```

