# Kubernetes Network Policies – Ingress vs Egress vs EgressDeny

> This document explains how **network policies control traffic between pods and external systems in Kubernetes**.

---

## Core Idea

Both **Ingress** and **Egress** rules allow traffic, but they control **different directions**.

| Policy Type    | Purpose                                        |
|----------------|------------------------------------------------|
| **Ingress**    | Allows traffic **coming INTO a pod**           |
| **Egress**     | Allows traffic **leaving FROM a pod**          |
| **EgressDeny** | Explicitly **blocks outgoing traffic** from a pod |

> **Key Point:** Ingress and Egress *allow* traffic, but the direction they control is opposite. EgressDeny *explicitly restricts* traffic.

---

## 1. Ingress Rule (Traffic Coming Into a Pod)

### Example

```yaml
endpointSelector:
  matchLabels:
    app: backend
ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
```

### Meaning

| Field             | What it means               |
|-------------------|-----------------------------|
| `endpointSelector` | Destination pod (backend)  |
| `fromEndpoints`   | Source pod (frontend)       |

### Traffic Flow

```
frontend pod  ─────►  backend pod
   (source)             (destination)
        ✅ Allowed

random pod  ─────►  backend pod
                        ❌ Blocked
```

### Rule Interpretation

- `endpointSelector` → **destination**
- `fromEndpoints` → **source**

---

## 2. Egress Rule (Traffic Going Out of a Pod)

### Example

```yaml
endpointSelector:
  matchLabels:
    app: backend
egress:
  - toEndpoints:
    - matchLabels:
        app: database
```

### Meaning

| Field             | What it means                |
|-------------------|------------------------------|
| `endpointSelector` | Source pod (backend)        |
| `toEndpoints`     | Destination pod (database)   |

### Traffic Flow

```
backend pod  ─────►  database pod
  (source)              (destination)
        ✅ Allowed
```

### Rule Interpretation

- `endpointSelector` → **source**
- `toEndpoints` → **destination**

---

## 3. Egress Deny (Explicit Traffic Restriction)

Cilium supports explicit deny rules using `egressDeny`. This blocks specific outgoing traffic from a pod.

### Example – Block frontend from accessing the database

```yaml
endpointSelector:
  matchLabels:
    app: frontend
egressDeny:
  - toEndpoints:
    - matchLabels:
        app: database
```

### Result

| Source Pod | Destination Pod | Result       |
|------------|-----------------|--------------|
| frontend   | backend         | ✅ Allowed   |
| frontend   | database        | ❌ Denied    |

### Traffic Flow

```
frontend pod  ─────►  database pod
                          ❌ Blocked
```

---

## 4. Quick Comparison

| Rule Type    | `endpointSelector`  | Other Field                        |
|--------------|---------------------|------------------------------------|
| Ingress      | Destination pod     | `fromEndpoints` = Source pod       |
| Egress       | Source pod          | `toEndpoints` = Destination pod    |
| EgressDeny   | Source pod          | Blocks specified destination       |

---

## 5. Easy Way to Remember

### Ingress
```
Someone → My Pod
```
- Policy is placed on the **destination** pod
- `endpointSelector` = **my pod** (who I am)
- `fromEndpoints` = **who can access me**

### Egress
```
My Pod → Someone
```
- Policy is placed on the **source** pod
- `endpointSelector` = **my pod** (who I am)
- `toEndpoints` = **where I can go**

---

## 6. Visual Summary

```
Ingress:
  frontend ─────► backend
  (source)        (destination)
  fromEndpoints   endpointSelector

Egress:
  backend ─────► database
  (source)        (destination)
  endpointSelector  toEndpoints
```

---

## 7. Traffic Types Controlled by Network Policies

| Traffic Type           | Direction          | Controlled By      | Example                    | Explanation                             |
|------------------------|--------------------|--------------------|----------------------------|-----------------------------------------|
| Pod → Pod              | Internal cluster   | Ingress or Egress  | frontend → backend         | Backend ingress allows frontend         |
| Pod → External Internet| Outgoing           | Egress             | backend → github.com       | Backend allowed to access external URLs |
| External → Pod         | Incoming           | Ingress            | User → frontend            | Internet can reach frontend pod         |
| Pod → Cluster Services | Internal           | Egress             | pod → CoreDNS              | Pod allowed to resolve DNS              |
| Pod → Database         | Internal cluster   | Egress or Ingress  | backend → database         | Backend allowed to access DB            |
| Random Pod → Backend   | Internal cluster   | Ingress            | random → backend           | Blocked if not in allowlist             |

---

## 8. Direction Visualization

| Flow                   | Policy Checked      |
|------------------------|---------------------|
| frontend → backend     | Backend **Ingress** |
| backend → database     | Backend **Egress**  |
| Internet → frontend    | Frontend **Ingress**|
| pod → internet         | Pod **Egress**      |

---

## 9. Important Rule – Both Sides Must Allow Traffic

> Traffic works **only if both sides allow it**.

| Source Egress | Destination Ingress | Result               |
|---------------|---------------------|----------------------|
| ✅ Allowed    | ✅ Allowed           | ✅ Traffic Flows     |
| ❌ Blocked    | ✅ Allowed           | ❌ Traffic Blocked   |
| ✅ Allowed    | ❌ Blocked           | ❌ Traffic Blocked   |
