# Kubernetes Service → Endpoints → iptables (kube-proxy) Lab

## Objective

Understand how **Kubernetes Services route traffic to Pods using kube-proxy and iptables**.

This lab demonstrates:
- How a **Service forwards traffic to Pods**
- How **Endpoints are created**
- How **kube-proxy updates iptables rules**
- How traffic automatically updates when **Pods change**

---

## Lab Environment

Check cluster information:

```bash
kind get clusters
kubectl get nodes
```

Example output:

```
NAME                         STATUS   ROLES           AGE
iptables-lab-control-plane   Ready    control-plane   5m
```

---

## Step 1 — Create Deployment

Create an nginx deployment with 2 replicas:

```bash
kubectl create deployment nginx-demo --image=nginx --replicas=2
```

Check the pods:

```bash
kubectl get pods -o wide
```

Example output:

```
NAME                   READY   STATUS    IP
nginx-demo-xxxxx       1/1     Running   10.244.0.12
nginx-demo-yyyyy       1/1     Running   10.244.0.13
```

> These Pod IPs become the **Service Endpoints**.

---

## Step 2 — Create Service

Expose the deployment as a ClusterIP Service:

```bash
kubectl expose deployment nginx-demo --port=80
```

Check the service:

```bash
kubectl get svc
```

Example output:

```
NAME         TYPE        CLUSTER-IP
nginx-demo   ClusterIP   10.96.239.59
```

> The Service now routes traffic to the nginx pods.

---

## Step 3 — Observe iptables Rules

Enter the kind control-plane node container:

```bash
docker exec -it iptables-lab-control-plane sh
```

Check iptables rules:

```bash
iptables -t nat -L | grep KUBE-SEP
```

Example output:

```
/* default/nginx-demo -> 10.244.0.12:80 */
statistic mode random probability 0.50000000000

/* default/nginx-demo -> 10.244.0.13:80 */
```

### What This Means

Service `nginx-demo` forwards traffic to two backend pods:

```
Service (10.96.239.59)
  ↓
10.244.0.12:80  (50%)
10.244.0.13:80  (50%)
```

> The `probability` rule performs **iptables-based load balancing**.

---

## Step 4 — Delete Pods

Delete all pods:

```bash
kubectl delete pods -l app=nginx-demo
```

The Deployment controller **automatically recreates** new pods. Check them:

```bash
kubectl get pods -o wide
```

Example output:

```
NAME                   READY   STATUS    IP
nginx-demo-aaaaa       1/1     Running   10.244.0.14
nginx-demo-bbbbb       1/1     Running   10.244.0.15
```

> Pod IPs have changed — new IPs assigned to the new pods.

---

## Step 5 — Observe iptables Update

Check iptables rules again:

```bash
iptables -t nat -L | grep KUBE-SEP
```

Example output:

```
/* default/nginx-demo -> 10.244.0.14:80 */
statistic mode random probability 0.50000000000

/* default/nginx-demo -> 10.244.0.15:80 */
```

> Old pod IPs were **automatically removed** and replaced with the new ones.

---

## What Happened Internally

When pods change, Kubernetes automatically updates networking:

```
Pod Created / Deleted
        ↓
Endpoint Controller updates Endpoints
        ↓
API Server updated
        ↓
kube-proxy detects change
        ↓
kube-proxy rewrites iptables rules
```

---

## Actual Traffic Flow

Packet routing inside the cluster:

```
Client Pod
   ↓
Service IP
   ↓
iptables rule match
   ↓
DNAT rewrite
   ↓
Backend Pod IP
```

### DNAT Explained

**Before** iptables rewrite:
```
SRC: pod-ip
DST: service-ip
```

**After** iptables rewrite:
```
SRC: pod-ip
DST: backend-pod-ip
```

> This is called **DNAT (Destination NAT)** — the destination is rewritten from Service IP to actual Pod IP.

---

## iptables Chain Flow

Full packet traversal path:

```
Client
  ↓
KUBE-SERVICES
  ↓
KUBE-SVC-XXXX
  ↓
Load balancing rule
  ↓
KUBE-SEP-XXXX
  ↓
Pod IP
```

---

## Why Random Probability Appears

Example rule:

```
statistic mode random probability 0.50000000000
```

Meaning:

```
50% traffic → Pod A
50% traffic → Pod B
```

> This is how iptables performs **round-robin style load balancing** — no smart health checking, just pure probability.

---

## Production Scenario Simulated

This lab simulates a real production pod failure scenario:

```
Pod crash
   ↓
Endpoint removed
   ↓
kube-proxy updates iptables
   ↓
Traffic redirected to healthy pods
```

> Users do **not experience downtime**. This demonstrates **Kubernetes self-healing networking**.

---

## Useful Debug Commands

```bash
# Check endpoints
kubectl get endpoints nginx-demo

# Check EndpointSlices
kubectl get endpointslices

# Check kube-proxy logs
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Check service iptables rules
iptables-save | grep nginx-demo
```

---

## Important Production Insight

iptables works well for small clusters. But in large clusters:

```
10,000 services
50,000 pods
→ iptables rules become very large and slow
```

Many organizations now use **Cilium** instead of kube-proxy:

```
Service
   ↓
eBPF map lookup   ← O(1), constant time regardless of cluster size
   ↓
Pod
```

---

## Kubernetes Debugging Commands

### `kubectl create deployment`

```bash
kubectl create deployment nginx-demo --image=nginx --replicas=2
```

Architecture:

```
Deployment
   ↓
ReplicaSet
   ↓
Pods
```

Used for: Web servers, APIs, Microservices (stateless applications)

---

### `kubectl run`

Create a **temporary debug pod**:

```bash
kubectl run test --image=busybox -it --rm -- sh
```

Flow:

```
kubectl run
     ↓
Creates temporary pod
     ↓
Opens shell
     ↓
Pod deleted on exit
```

Use cases:
- Debug networking
- Test service connectivity
- DNS testing

```bash
wget nginx-demo          # test HTTP to service
ping <pod-ip>            # test pod connectivity
nslookup <service-name>  # test DNS resolution
```

---

### `kubectl exec`

Run commands inside an **existing running pod**:

```bash
kubectl exec -it <pod-name> -- sh

# Example
kubectl exec -it nginx-demo-abc123 -- sh
```

Use cases:
- Debug applications
- Inspect container filesystem
- Run diagnostic commands

---

### HTTP Testing with `wget`

Send an HTTP request to a service:

```bash
wget -qO- nginx-demo
```

| Option | Meaning                     |
|--------|-----------------------------|
| `wget` | HTTP client                 |
| `-q`   | Quiet mode (no progress)    |
| `-O-`  | Print output to terminal    |

Traffic flow:

```
Client Pod
   ↓
Service IP
   ↓
kube-proxy (iptables)
   ↓
Backend Pod
```

---

### Network Testing with `ping`

Check connectivity between pods:

```bash
ping 10.244.0.5
```

Used to test:
- Pod-to-pod networking
- CNI functionality
- Basic connectivity

```
Pod A
  ↓
CNI network
  ↓
Pod B
```

---

### Typical Kubernetes Debug Flow

```bash
# 1. Spin up a debug pod
kubectl run test --image=busybox -it --rm -- sh

# 2. Inside the pod — test connectivity
ping <pod-ip>
wget <service-name>

# 3. Verify networking and service routing
nslookup <service-name>
```

---

## Quick Command Summary

| Command                      | Purpose                                  |
|------------------------------|------------------------------------------|
| `kubectl create deployment`  | Create application workload              |
| `kubectl run`                | Create temporary debug pod               |
| `kubectl exec`               | Run commands inside a running container  |
| `wget`                       | Test HTTP connectivity to a service      |
| `ping`                       | Test basic network connectivity          |
