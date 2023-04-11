## KIND local environment

<img src="./KIND-diagram.png?raw=true" width="800">
KIND Source: https://github.com/kubernetes-sigs/kind (https://github.com/kubernetes-sigs/kind/tree/main/images/base)

### Install KIND 
```
### Install docker, kubectl, etc.

### Instal KIND 

$ curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind (Note: k8s v1.25.3)
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

### Vault

```
$ helm repo add hashicorp https://helm.releases.hashicorp.com
$ helm repo update
$ helm upgrade -i vault hashicorp/vault --set='server.ha.enabled=true' --set='server.ha.raft.enabled=true' -n vault --create-namespace
$ kubectl get all -n vault -o wide
NAME                                        READY   STATUS    RESTARTS   AGE    IP                NODE             NOMINATED NODE   READINESS GATES
pod/vault-0                                 0/1     Running   0          59s    192.168.255.133   gitops-worker3   <none>           <none>
pod/vault-1                                 0/1     Running   0          59s    192.168.183.70    gitops-worker    <none>           <none>
pod/vault-2                                 0/1     Running   0          58s    192.168.32.71     gitops-worker2   <none>           <none>
pod/vault-agent-injector-59b9c84fd8-vkhsm   1/1     Running   0          3m5s   192.168.183.68    gitops-worker    <none>           <none>

$ kubectl -n vault exec -it vault-0 -- vault operator init -status
Vault is not initialized
command terminated with exit code 2

$ kubectl -n vault exec -it vault-0 -- vault operator init
Unseal Key 1: zoA4QCi5oTyqCGS7F4/+5ujrFs1vSdi1dabdJDYXp1JU
Unseal Key 2: GTL4VcufEJAUhJfHzqypg1AKN7GtxlCTTp8P+j+C06AP
Unseal Key 3: R1vTxwrwiYND0j0/siVE2TDIBpa9lQleKy+HS80j/6Xb
Unseal Key 4: F0iFITqZ/U9GwKUWCtkMrrHdxWhAUKjV8v1BzCnVwjzS
Unseal Key 5: i2n20400KRdGJRAMK2loyHUb5DzIbto+EVSu2HUdkylN

Initial Root Token: hvs.RRI2i8QiLAw85IjnqzjYjpbV

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.

Note: When Vault is initialized, it will be put into sealed mode, meaning that the
that it knows how to access the storage layer, but cannot decrypt any of the
content. When Vault is in a sealed state, it is akin to a bank vault where the
assets are secure, but no actions can take place. To be able to interact with
Vault, it must be unsealed.

$ kubectl -n vault exec -it vault-0 -- vault operator unseal
$ kubectl -n vault exec -it vault-0 -- vault operator unseal
$ kubectl -n vault exec -it vault-0 -- vault operator unseal
$ kubectl -n vault exec -ti vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
$ kubectl -n vault exec -it vault-1 -- vault operator unseal
$ kubectl -n vault exec -it vault-1 -- vault operator unseal
$ kubectl -n vault exec -it vault-1 -- vault operator unseal
$ kubectl -n vault exec -ti vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
$ kubectl -n vault exec -it vault-2 -- vault operator unseal
$ kubectl -n vault exec -it vault-2 -- vault operator unseal
$ kubectl -n vault exec -it vault-2 -- vault operator unseal
$ kubectl get po -n vault -o wide
NAME                                    READY   STATUS    RESTARTS   AGE   IP                NODE             NOMINATED NODE   READINESS GATES
vault-0                                 1/1     Running   0          13m   192.168.255.133   gitops-worker3   <none>           <none>
vault-1                                 1/1     Running   0          13m   192.168.183.70    gitops-worker    <none>           <none>
vault-2                                 1/1     Running   0          13m   192.168.32.71     gitops-worker2   <none>           <none>
vault-agent-injector-59b9c84fd8-vkhsm   1/1     Running   0          15m   192.168.183.68    gitops-worker    <none>           <none>

$ kubectl -n vault exec -it vault-0 -- vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.RRI2i8QiLAw85IjnqzjYjpbV
token_accessor       wC41FvwC1UvzAphcLVCSg4BJ
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]

Initial Root Token: hvs.RRI2i8QiLAw85IjnqzjYjpbV
$ kubectl -n vault exec -ti vault-0 -- vault operator raft list-peers
Node                                    Address                        State       Voter
----                                    -------                        -----       -----
3895811d-871d-4839-c83c-c8c7102ede48    vault-0.vault-internal:8201    leader      true
03c2ebf1-c21f-cde9-9534-15cf9d4a6504    vault-1.vault-internal:8201    follower    true
63983551-e6f8-7ebe-fc60-0cdc66469b39    vault-2.vault-internal:8201    follower    true

```
### App: Using the Agent Injector 

<img src="./inject_vault.jpeg?raw=true" width="800">

```
$ kubectl exec -n vault -it vault-0 -- /bin/sh

/ $ vault secrets enable -path=internal kv-v2
Success! Enabled the kv-v2 secrets engine at: internal/
/ $ vault kv put internal/database/config username="db-readonly-username" password="db-secret-password"
======== Secret Path ========
internal/data/database/config

======= Metadata =======
Key                Value
---                -----
created_time       2023-04-11T09:29:13.946974464Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
/ $ vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/
/ $ vault write auth/kubernetes/config \
>   kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
Success! Data written to: auth/kubernetes/config
/ $ vault policy write internal-app - <<EOF
> path "internal/data/database/config" {
> capabilities = ["read"]
> }
> EOF
Success! Uploaded policy: internal-app
/ $ vault write auth/kubernetes/role/internal-app \
>   bound_service_account_names=internal-app \
>   bound_service_account_namespaces=default \
>   policies=internal-app \
>   ttl=24h
Success! Data written to: auth/kubernetes/role/internal-app
/ $ 

$ kubectl create sa internal-app
serviceaccount/internal-app created
$ kubectl apply -f internal-app-deploy.yaml 
deployment.apps/orgchart created

$ kubectl get po
NAME                        READY   STATUS    RESTARTS   AGE
orgchart-67fbfdcc7c-sqc2g   2/2     Running   0          77m
$ kubectl logs orgchart-67fbfdcc7c-sqc2g 
Defaulted container "orgchart" out of: orgchart, vault-agent, vault-agent-init (init)
Listening on port 8000...

$ kubectl logs orgchart-67fbfdcc7c-sqc2g
$ kubectl logs orgchart-67fbfdcc7c-sqc2g -c vault-agent-init
$ kubectl logs orgchart-67fbfdcc7c-sqc2g -c vault-agent
$ kubectl logs orgchart-67fbfdcc7c-sqc2g -c orgchart


$ kubectl exec \
>   $(kubectl get pod -l app=orgchart -o jsonpath="{.items[0].metadata.name}") \
>   --container orgchart -- cat /vault/secrets/database-config.txt
postgresql://db-readonly-username:db-secret-password@postgres:5432/wizard
```


### Clean environment

```
$ kind delete cluster --name=gitops

$ kind delete cluster --name=gitops
Deleting cluster "devsecops" ...
[1]+  Killed                  linkerd viz dashboard
```

