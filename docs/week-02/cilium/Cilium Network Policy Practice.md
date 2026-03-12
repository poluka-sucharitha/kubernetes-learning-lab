# Cilium Network Policy Practice

## Part 1: Create Clean Kind Cluster for Cilium

Use a kind cluster with default CNI disabled and kube-proxy disabled.

### 1. Create config file

```bash
cat <<EOF > kind.yml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
nodes:
- role: control-plane
EOF
```

### 2. Delete old cluster if present

```bash
kind delete cluster --name kind
```

### 3. Create new cluster

```bash
kind create cluster --config kind.yml
```

### 4. Check cluster

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Part 2: Install Cilium

### 1. Install Cilium CLI if not already installed

```bash
curl -L --remote-name https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
sudo tar -xvf cilium-linux-amd64.tar.gz -C /usr/local/bin
cilium version
```

### 2. Install Cilium in cluster

```bash
cilium install
```

### 3. Verify

```bash
cilium status
kubectl get pods -n kube-system
```

---

## Part 3: Enable Hubble

### 1. Enable Hubble UI

```bash
cilium hubble enable --ui
```

### 2. Verify again

```bash
cilium status
kubectl get pods -n kube-system
kubectl get svc -n kube-system
```

### 3. Port-forward Hubble UI

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

**For remote VM with browser access from outside:**

```bash
kubectl -n kube-system port-forward --address 0.0.0.0 svc/hubble-ui 12000:80
```

---

## Part 4: Deploy Demo Application

We will create:
- **Backend**: nginx server
- **Frontend**: busybox client

### 1. Create namespace

```bash
kubectl create ns demo
```

### 2. Create backend deployment

```bash
kubectl -n demo create deployment backend --image=nginx
```

### 3. Expose backend as service

```bash
kubectl -n demo expose deployment backend --port=80 --name=backend-svc
```

### 4. Create frontend deployment

```bash
kubectl -n demo create deployment frontend --image=busybox -- sleep 3600
```

### 5. Check deployments and pods

```bash
kubectl get deploy -n demo
kubectl get pods -n demo -o wide
kubectl get svc -n demo
```

### 6. Label deployments properly

```bash
kubectl -n demo label deploy/frontend app=frontend --overwrite
kubectl -n demo label deploy/backend app=backend --overwrite
```

### 7. Confirm labels

```bash
kubectl get deploy -n demo --show-labels
kubectl get pods -n demo --show-labels
```

---

## Part 5: Test Baseline Connectivity

Before applying policy, the frontend should reach the backend.

```bash
kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```

If working, you should see nginx HTML output.

**Alternative: Open shell inside frontend:**

```bash
kubectl -n demo exec -it deploy/frontend -- sh
```

Then run inside the pod:

```bash
wget -qO- http://backend-svc
```

Exit with:

```bash
exit
```

---

## Part 6: Apply DENY Policy

This policy blocks `frontend → backend` traffic.

### 1. Create deny policy file

```bash
cat <<EOF > deny-egress.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: deny-frontend-to-backend
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egressDeny:
  - toEndpoints:
    - matchLabels:
        app: backend
EOF
```

### 2. Apply deny policy

```bash
kubectl apply -f deny-egress.yaml
```

### 3. Verify policy

```bash
kubectl get ciliumnetworkpolicy -n demo
kubectl describe ciliumnetworkpolicy deny-frontend-to-backend -n demo
```

### 4. Test again

```bash
kubectl -n demo exec -it deploy/frontend -- wget -qO- --timeout=3 http://backend-svc || echo "Denied!"
```

**Expected result:**

```
Denied!
```

---

## Part 7: Observe Dropped Traffic in Hubble

Open another terminal and run:

```bash
hubble observe --verdict DROPPED
```

Then generate traffic again:

```bash
kubectl -n demo exec -it deploy/frontend -- wget -qO- --timeout=3 http://backend-svc || echo "Denied!"
```

You should see dropped flow in Hubble.

---

## Part 8: Remove Deny Policy

Before testing allow, delete the deny policy first.

```bash
kubectl delete ciliumnetworkpolicy deny-frontend-to-backend -n demo
```

Check:

```bash
kubectl get ciliumnetworkpolicy -n demo
```

Test connectivity again:

```bash
kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```

It should work again.

---

## Part 9: Apply ALLOW Policy

Your earlier allow policy used labels `server` and `client`, but your actual deployments are `backend` and `frontend`. Use this corrected policy.

### 1. Create allow policy file

```bash
cat <<EOF > allow.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
EOF
```

### 2. Apply allow policy

```bash
kubectl apply -f allow.yaml
```

### 3. Verify

```bash
kubectl get ciliumnetworkpolicy -n demo
kubectl describe ciliumnetworkpolicy allow-frontend-to-backend -n demo
```

### 4. Test traffic

```bash
kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```

It should work.

---

## Part 10: Important Understanding

### Deny Policy Meaning

```yaml
endpointSelector:
  matchLabels:
    app: frontend
gressDeny:
- toEndpoints:
  - matchLabels:
      app: backend
```

**Meaning:**
- Select pod: `frontend`
- Block its outgoing traffic
- Destination: `backend`

**Result:** `frontend → backend = blocked`

### Allow Policy Meaning

```yaml
endpointSelector:
  matchLabels:
    app: backend
ingress:
- fromEndpoints:
  - matchLabels:
      app: frontend
```

**Meaning:**
- Select pod: `backend`
- Allow incoming traffic
- Source: `frontend`

**Result:** `frontend → backend = allowed`

---

## Part 11: Useful Commands for Practice

### Check pods
```bash
kubectl get pods -n demo -o wide
```

### Check services
```bash
kubectl get svc -n demo
```

### Check endpoints
```bash
kubectl get endpoints -n demo
```

### Check Cilium policies
```bash
kubectl get ciliumnetworkpolicy -n demo
```

### Describe one policy
```bash
kubectl describe ciliumnetworkpolicy allow-frontend-to-backend -n demo
```

### Enter frontend pod shell
```bash
kubectl -n demo exec -it deploy/frontend -- sh
```

### Test DNS inside pod
```bash
kubectl -n demo exec -it deploy/frontend -- nslookup backend-svc
```

### Test HTTP
```bash
kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```

### Watch dropped traffic
```bash
hubble observe --verdict DROPPED
```

### Watch all flows
```bash
hubble observe
```

---

## Part 12: Full Quick Practice Version

If you want only the exact command sequence:

```bash
kind delete cluster --name kind

cat <<EOF > kind.yml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
nodes:
- role: control-plane
EOF

kind create cluster --config kind.yml

cilium install
cilium status

cilium hubble enable --ui
kubectl -n kube-system port-forward svc/hubble-ui 12000:80

kubectl create ns demo
kubectl -n demo create deployment backend --image=nginx
kubectl -n demo expose deployment backend --port=80 --name=backend-svc
kubectl -n demo create deployment frontend --image=busybox -- sleep 3600

kubectl -n demo label deploy/frontend app=frontend --overwrite
kubectl -n demo label deploy/backend app=backend --overwrite

kubectl get pods -n demo --show-labels
kubectl get svc -n demo

kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```

### Create deny policy:

```bash
cat <<EOF > deny-egress.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: deny-frontend-to-backend
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egressDeny:
  - toEndpoints:
    - matchLabels:
        app: backend
EOF

kubectl apply -f deny-egress.yaml
kubectl get ciliumnetworkpolicy -n demo
kubectl -n demo exec -it deploy/frontend -- wget -qO- --timeout=3 http://backend-svc || echo "Denied!"
```

### Delete deny policy:

```bash
kubectl delete ciliumnetworkpolicy deny-frontend-to-backend -n demo
kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```

### Create allow policy:

```bash
cat <<EOF > allow.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
EOF

kubectl apply -f allow.yaml
kubectl get ciliumnetworkpolicy -n demo
kubectl -n demo exec -it deploy/frontend -- wget -qO- http://backend-svc
```