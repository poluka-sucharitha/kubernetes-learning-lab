# Kubernetes Networking Basics

Kubernetes networking enables communication between pods, services, and external clients.

**The goal of Kubernetes networking:**
- Every pod gets its own IP address
- Pods can communicate directly
- Services provide stable access to pods

---

## 1. Pod Networking

Each pod gets its own IP address.

```
Pod1 → 10.244.1.5
Pod2 → 10.244.2.7
```

Pods can communicate directly using IP:

```
PodA (10.244.1.5)  ─────►  PodB (10.244.2.7)
```

> This is **Layer 3 communication** (IP to IP).

---

## 2. Kubernetes Networking Rule

Kubernetes has one fundamental networking rule:

> **Every pod can communicate with every other pod without NAT.**

```
Pod A (Node1)  ─────►  Pod B (Node2)
```

CNI plugins handle this networking. Examples:

- Flannel
- Calico
- Cilium
- Weave

---

## 3. Problem With Pod IPs

Pod IPs are **dynamic** — they change when a pod restarts.

```
Before restart:  Pod1 → 10.244.1.5
After restart:   Pod1 → 10.244.3.8  ← different IP
```

Applications depending on the old IP will **break**.

This is why Kubernetes introduces **Services**.

---

## 4. Kubernetes Service

A Service provides a **stable virtual IP** that doesn't change.

```
Service IP → 10.96.0.10
```

Instead of connecting to pods directly:
```
Client → Pod IP   ❌ (unreliable)
```

Clients connect to the service:
```
Client → Service IP → Pod1
                   → Pod2
                   → Pod3
```

---

## 5. Why Services Are Needed

Pods scale dynamically:

```
Today:    3 pods
Tomorrow: 5 pods
```

A Service provides:
- **Stable IP** — never changes
- **Load balancing** — distributes traffic across pods
- **Service discovery** — apps find each other by name

---

## 6. kube-proxy

`kube-proxy` runs on **every node**. It watches:
- Services
- Endpoints
- EndpointSlices

When a Service is created, kube-proxy creates **iptables rules** that handle traffic routing.

---

## 7. Important Concept

> The **Service object does NOT route traffic** by itself.

Instead:
```
kube-proxy  →  installs iptables rules
iptables    →  routes traffic to pods
```

A Service is just a **logical abstraction**.

---

## 8. Packet Flow (kube-proxy)

```
Client
  ↓
Node Network Interface
  ↓
Linux Kernel
  ↓
iptables rules  (created by kube-proxy)
  ↓
Backend Pod selected
  ↓
Pod receives request
```

> iptables performs the load balancing.

---

## 9. Example Service Routing

```
Service IP → 10.96.0.10

Backend pods:
  10.244.1.5
  10.244.2.7
  10.244.3.2
```

iptables rule logic:
```
if destination == 10.96.0.10
    randomly choose a pod
```

Example result:
```
10.96.0.10  ─────►  10.244.2.7
```

---

## 10. Communication Types in Kubernetes

### Pod to Pod
```
PodA (10.244.1.5)  ─────►  PodB (10.244.2.7)
```
> **Layer 3** — IP communication

---

### Client to Service
```
curl 10.96.0.10:80
```
> **Layer 4** — IP + Port communication

---

### HTTP Routing (Ingress)
```
GET  /products
POST /login
```
> **Layer 7** — Application-level routing

---

## 11. What Happens Without a Service

```bash
kubectl run nginx --image=nginx
# Pod IP → 10.244.1.5

curl 10.244.1.5
```

Traffic flow:
```
Client → Pod IP → Pod
```

In this case:
- kube-proxy does **nothing**
- No iptables rules are created
- Pod IP is accessed **directly**

---

## 12. iptables Processing

iptables processes rules **sequentially** — one by one:

```
packet
  ↓
rule 1 → match? No
  ↓
rule 2 → match? No
  ↓
rule 3 → match? Yes ✅
  ↓
forward
```

In large clusters with **1000 services / 10,000 pods**, this creates thousands of rules and **slows packet processing significantly**.

---

## 13. Why eBPF / Cilium Was Introduced

**iptables** — sequential rule scanning:
```
packet → rule1 → rule2 → rule3 → ... → match
```

**eBPF** — hash map lookup:
```
packet → lookup(service_ip) → pod
```

> Map lookup is **O(1)** — same speed regardless of how many rules exist.

---

## 14. Quick Comparison

| Feature       | kube-proxy + iptables | eBPF (Cilium)   |
|---------------|-----------------------|-----------------|
| Routing       | iptables rules        | BPF maps        |
| Processing    | Sequential            | Map lookup      |
| Performance   | Slower                | Faster          |
| Scalability   | Limited               | Very high       |

---

## 15. Simple Networking Flow

**Traditional Kubernetes:**
```
Client
  ↓
Service
  ↓
kube-proxy
  ↓
iptables
  ↓
Pod
```

**Cilium (eBPF):**
```
Client
  ↓
Service
  ↓
eBPF program
  ↓
BPF map lookup
  ↓
Pod
```

---

## 16. Quick Recall (Interview)

### OSI Layer Meanings
| Layer | What it handles        |
|-------|------------------------|
| L3    | IP communication       |
| L4    | Port communication     |
| L7    | Application routing    |

### Kubernetes Networking Summary
| Component  | Role                                  |
|------------|---------------------------------------|
| Pod        | Gets a unique IP                      |
| Service    | Stable virtual IP (doesn't change)    |
| kube-proxy | Installs iptables rules on each node  |
| iptables   | Forwards traffic to backend pods      |
