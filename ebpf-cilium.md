# eBPF & Cilium — Kubernetes Networking (Beginner Notes)

This document explains:
- What eBPF is
- Why Cilium uses eBPF
- How map lookups work
- How traffic flows inside the kernel
- How Cilium improves networking & security

---

## 1. What is eBPF?

**eBPF** (Extended Berkeley Packet Filter) is a Linux kernel technology that allows programs to run inside the kernel safely.

Instead of sending packets to userspace tools, the kernel itself processes networking logic.

**eBPF can be used for:**
- **Networking**
- **Security enforcement**
- **Monitoring**
- **Observability**
- **Tracing**

---

## 2. Why eBPF Exists

Traditional Linux networking tools use **rule-based processing**.

### Example (iptables):
```
packet
  ↓
rule1
rule2
rule3
rule4
...
match
```

### Problem:
- More rules → slower processing
- Large Kubernetes clusters may create thousands of rules
- eBPF solves this using **map lookups (hash tables)**

---

## 3. Map Lookup Concept (Very Important)

eBPF stores networking data inside **BPF Maps**.

Think of this like a **HashMap / dictionary**.

### Example map:

| Key | Value |
|-----|-------|
| Service IP | Pod IPs |

### Example:
```
10.96.0.10 → [10.244.1.5, 10.244.2.7]
```

### Request arrives:
```bash
curl 10.96.0.10
```

### Kernel performs lookup:
```
lookup(10.96.0.10)
```

### Result:
```
10.244.2.7
```

Packet forwarded to the selected pod.

### Why this is fast:
- **HashMap lookup = O(1)**
- Instead of scanning thousands of rules

---

## 4. Packet Flow Using eBPF

When a packet arrives:
```
Packet
  ↓
Linux Kernel
  ↓
eBPF program
  ↓
BPF Map Lookup
  ↓
Decision (route / allow / deny)
```

### Example:
```
Service IP → Pod IP
```

---

## 5. What is Cilium?

**Cilium** is a Kubernetes CNI that uses eBPF for networking and security.

It replaces:
- **kube-proxy**
- **iptables**

Meaning traffic routing happens using kernel-level eBPF programs.

---

## 6. Kubernetes Networking With Cilium

### Traditional Kubernetes networking:
```
Client
  ↓
Service
  ↓
kube-proxy
  ↓
tables rules
  ↓
Pod
```

### Cilium networking:
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

This removes the need for iptables rule scanning.

---

## 7. iptables vs eBPF

| Feature | iptables | eBPF |
|---------|----------|------|
| Processing | rule matching | map lookup |
| Speed | slower | very fast |
| Scalability | limited | very high |
| Used by | kube-proxy | Cilium |

### Example comparison:

**iptables:**
```
packet
  ↓
rule1
rule2
rule3
rule4
...
```

**eBPF:**
```
packet
  ↓
lookup(service_ip)
  ↓
pod
```

---

## 8. eBPF Hook Points (Where Programs Attach)
eBPF programs attach to different points in the Linux networking stack.

### Important hook points:

| Hook | Purpose |
|------|---------|
| XDP | earliest packet processing |
| TC | traffic control |
| Socket hooks | application-level traffic |

### Typical packet path:
```
Network Card
  ↓
XDP hook
  ↓
Linux network stack
  ↓
TC hook
  ↓
BPF map lookup
  ↓
Pod network interface
  ↓
Pod container
```

---

## 9. Security Policies in Cilium

Cilium can enforce policies at multiple layers.

### Layer 3 Policy (IP Level)
Controls which pods can talk to which pods.

**Example:**
```
frontend → backend allowed
frontend → database denied
```

### Layer 4 Policy (Port Level)
Controls which ports are allowed.

**Example:**
```
frontend → backend TCP 80 allowed
frontend → backend TCP 22 denied
```

### Layer 7 Policy (Application Level)
Controls application requests (HTTP APIs).

**Example:**
```
Allow  : GET /products
Allow  : POST /login
Deny   : DELETE /users
```

This allows API-level security.

---

## 10. Observability with Hubble

Cilium provides a tool called **Hubble**.

Hubble shows real-time network flows.

### Example output:
```
frontend → backend   allowed
backend → database   allowed
frontend → database  denied
```

### Benefits:
- Visualize service communication
- Debug network issues
- Security monitoring

---

## 11. Example Microservice Traffic

### Example application architecture:
```
User
  ↓
Frontend
  ↓
API Gateway
  ↓
Auth Service
  ↓
Payment Service
  ↓
Database
```

### Example security policies:
```
Frontend → API Gateway allowed
API Gateway → Auth allowed
API Gateway → Payment allowed
Payment → Database allowed
Frontend → Database denied
```

This approach is called: **Zero Trust Networking**

---

## 12. Quick Recall (Interview Summary)

| Concept | Description |
|---------|-------------|
| **eBPF** | Linux kernel technology for fast networking and security |
| **Cilium** | Kubernetes CNI using eBPF |
| **Key Advantage** | iptables → sequential rules; eBPF → map lookup |
| **Layer Security** | L3 → IP communication; L4 → Port communication; L7 → Application request filtering |

---

## 13. One-Line Mental Model

```
ipables = rule scanning
eBPF = hash map lookup
```

**OR**

```
Old networking → rule based
Modern networking → program based
```