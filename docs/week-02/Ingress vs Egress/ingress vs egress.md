1️⃣ Ingress Rule (Traffic Coming Into a Pod)

Example:

endpointSelector:
  matchLabels:
    app: backend

ingress:
- fromEndpoints:
  - matchLabels:
      app: frontend
Meaning
Part	What it means
endpointSelector	Destination pod (backend)
fromEndpoints	Source pod (frontend)

So the flow becomes:

frontend pod  ─────► backend pod
        (source)       (destination)

✔ Allowed

But:

random pod ─────► backend pod

❌ Blocked

So for ingress:

endpointSelector → destination
fromEndpoints → source
2️⃣ Egress Rule (Traffic Going Out of a Pod)

Example:

endpointSelector:
  matchLabels:
    app: backend

egress:
- toEndpoints:
  - matchLabels:
      app: database
Meaning
Part	What it means
endpointSelector	Source pod (backend)
toEndpoints	Destination pod (database)

Flow:

backend pod ─────► database pod
      (source)        (destination)

✔ Allowed

3️⃣ Quick Comparison
Rule Type	endpointSelector	Other field
Ingress	Destination pod	fromEndpoints = Source
Egress	Source pod	toEndpoints = Destination
4️⃣ Easy Way to Remember
Ingress
Someone → My Pod

So the policy is on the destination pod.

endpointSelector = my pod
fromEndpoints = who can access me
Egress
My Pod → Someone

So the policy is on the source pod.

endpointSelector = my pod
toEndpoints = where I can go
5️⃣ Visual Summary
INGRESS
frontend ─────► backend
 source         destination
fromEndpoints   endpointSelector
EGRESS
backend ─────► database
 source         destination
endpointSelector  toEndpoints

✅ Short rule

Ingress  → controls incoming traffic
Egress   → controls outgoing traffic


# Kubernetes Network Policy – Ingress vs Egress

## Traffic Types Controlled by Network Policies

| Traffic Type | Direction | Controlled By | Example | Explanation |
|---|---|---|---|---|
| **Pod → Pod** | Internal cluster traffic | Ingress or Egress | `frontend → backend` | Backend ingress allows frontend |
| **Pod → External Internet** | Outgoing traffic | Egress | `backend → github.com` | Backend allowed to access external services |
| **External → Pod** | Incoming traffic | Ingress | `User → frontend` | Internet can reach frontend pod |
| **Pod → Cluster Services (DNS, API)** | Internal service access | Egress | `pod → CoreDNS` | Pod allowed to resolve DNS |
| **Pod → Database** | Internal cluster traffic | Egress or Ingress | `backend → database` | Backend allowed to access DB |
| **Random Pod → Backend** | Internal cluster traffic | Ingress | `random → backend` | Blocked if not allowed in ingress |

---

# Rule Meaning

| Rule Type | Controls | Example |
|---|---|---|
| **Ingress** | Who can send traffic **to a pod** | `frontend → backend` |
| **Egress** | Where a pod can send traffic **from the pod** | `backend → database` |

---

# Direction Visualization

| Flow | Checked Policy |
|---|---|
| `frontend → backend` | Backend **Ingress** |
| `backend → database` | Backend **Egress** |
| `Internet → frontend` | Frontend **Ingress** |
| `pod → internet` | Pod **Egress** |

---

# Important Rule

Traffic works only if **both sides allow it**.

| Source | Destination | Result |
|---|---|---|
| Egress ✔ | Ingress ✔ | Traffic Allowed |
| Egress ❌ | Ingress ✔ | Blocked |
| Egress ✔ | Ingress ❌ | Blocked |

---

# Simple Memory Trick
Ingress = Incoming traffic to the pod
Egress = Outgoing traffic from the pod
