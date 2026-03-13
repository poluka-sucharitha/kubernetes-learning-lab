# Ingress vs Egress in Kubernetes Network Policies

## 1️⃣ Ingress Rule (Traffic Coming Into a Pod)

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

| Part | What it means |
|------|---------------|
| `endpointSelector` | Destination pod (backend) |
| `fromEndpoints` | Source pod (frontend) |

### Flow

**Allowed:**
```
frontend pod ──────► backend pod
  (source)       (destination)
```
✔ Allowed

**Not Allowed:**
```
random pod ──────► backend pod
```
❌ Blocked

### Key Points for Ingress

- `endpointSelector` → destination
- `fromEndpoints` → source

---

## 2️⃣ Egress Rule (Traffic Going Out of a Pod)

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

| Part | What it means |
|------|---------------|
| `endpointSelector` | Source pod (backend) |
| `toEndpoints` | Destination pod (database) |

### Flow

```
backend pod ──────► database pod
  (source)       (destination)
```
✔ Allowed

---

## 3️⃣ Quick Comparison

| Rule Type | endpointSelector | Other field |
|-----------|------------------|-------------|
| **Ingress** | Destination pod | `fromEndpoints` = Source |
| **Egress** | Source pod | `toEndpoints` = Destination |

---

## 4️⃣ Easy Way to Remember

### Ingress
> **Someone → My Pod**
>
> The policy is on the destination pod.
>
> - `endpointSelector` = my pod
> - `fromEndpoints` = who can access me

### Egress
> **My Pod → Someone**
>
> The policy is on the source pod.
>
> - `endpointSelector` = my pod
> - `toEndpoints` = where I can go

---

## 5️⃣ Visual Summary

### INGRESS
```
frontend ──────► backend
  source      destination
fromEndpoints   endpointSelector
```

### EGRESS
```
backend ──────► database
  source      destination
endpointSelector  toEndpoints
```

---

## ✅ Short Rule

- **Ingress** → controls incoming traffic
- **Egress** → controls outgoing traffic