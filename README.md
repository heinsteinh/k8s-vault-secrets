
## Passing Secrets: Using Vault with Kubernetes

### k8s:KIND local environment

<img src="./KIND-diagram.png?raw=true" width="800">

Note: CNI=Calico for this setup

### KIND install/setup
```
### Pre: Install docker, kubectl, helm.

### KIND environment setup

$ curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind (Note: k8s v1.25.3)
$ cd KIND/
###Create k8s Cluster and get credentials
$ kind create cluster --name gitops --config cluster-config.yaml
$ kind get kubeconfig --name="gitops" > admin.conf
$ export KUBECONFIG=./admin.conf 
### Calico -> REF: https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart#install-calico
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml
### Nginx Ingress
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

### Vault install

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
Vault, it must be unsealed. When vault was initialized, five (5) unsealed 
keys were provided representing the shards that will be used to construct the combined key. 
By default, three (3) keys are needed to reconstruct the combined key. Let’s begin the process
of unsealing the Vault for the vault-0 instance. Once these steps have been completed 
on the vault-0 instance, perform the vault operator join and vault operator 
unseal commands on the vault-1 & vault-2 instance.

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

Note: To confirm that the highly available Vault cluster is ready, login to the
vault-0 instance using the Initial Root Token provided by the vault
operator init command

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
### Vault from the command line 

```
### Next, we’ll need to exec into the Pod running Vault in order to configure it and add our secrets, like so:

$ kubectl exec -n vault -it vault-0 -- /bin/sh

### enable Vault’s Key Value v2 Secrets Engine, which will allow us to create and store a simple key-value secret, like so:

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

### Next, we’ll need to enable Vault’s built-in K8s auth, so that it will be able to authenticate with Vault using a Kubernetes Service Account Token that we can get from our running cluster, like so:

/ $ vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/

### Then we’ll need to add the K8s host IP to the Vault auth config:

/ $ vault write auth/kubernetes/config \
>   kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
Success! Data written to: auth/kubernetes/config

### Next, we’ll need to create a Vault policy called internal-app that will allow read access to our defined path within Vault:

/ $ vault policy write internal-app - <<EOF
> path "internal/data/database/config" {
> capabilities = ["read"]
> }
> EOF
Success! Uploaded policy: internal-app

### Then create a Vault role that includes references to the Vault role we just created, the K8s service account we’ll create in the next step, and the K8s namespace it will have access to within our Kubernetes cluster, like so:

/ $ vault write auth/kubernetes/role/internal-app \
>   bound_service_account_names=internal-app \
>   bound_service_account_namespaces=default \
>   policies=internal-app \
>   ttl=24h
Success! Data written to: auth/kubernetes/role/internal-app
/ $ exit

After exiting our exec session, we’ll need to create the Service Account our Vault role refers to above in kind – also called internal-app:

$ kubectl create sa internal-app
serviceaccount/internal-app created
```
### Demo1: App -> Using a manual init container to load secrets

<img src="./init-vault.jpeg?raw=true" width="800">

```
$ kubectl create configmap example-vault-agent-config --from-file=vault-agent-config.hcl
$ kubectl apply -f  pod-spec.yml
$ kubectl logs vault-agent-example -c  vault-agent-auth
$ kubectl logs vault-agent-example -c  nginx-container
$ kubectl exec vault-agent-example --container nginx-container -- cat /usr/share/nginx/html/index.html
  <html>
  <body>
  <p>DB Connection String:</p>postgresql://db-readonly-username:db-secret-password@postgres:5432/wizard
  
  </body>
  </html>

```

### Demo2: App -> Using the Agent Injector to make our life easier

<img src="./inject_vault.jpeg?raw=true" width="800">

```

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
### Conclusion: 
Vault can be used to securely inject secrets like database credentials into running Pods in Kubernetes so that your application can access them. Above, we looked at two ways to do this – manually and in an automated fashion. In both cases, an init container spins up a Vault Agent that authenticates with Vault, gets the secrets, and writes them to a local storage volume that your application can access during runtime.

### Clean environment

```
$ kind delete cluster --name=gitops
```

