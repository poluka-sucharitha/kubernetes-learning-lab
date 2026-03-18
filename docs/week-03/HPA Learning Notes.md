```md
# 📘 HPA Learning Notes (From This Conversation)

## 1. Types of HPA Metrics
- **Resource** → CPU, Memory (via metrics-server)
- **Pods** → Per-pod custom metrics (e.g., RPS per pod)
- **Object** → Metrics from a Kubernetes object (e.g., Service traffic)
- **External** → Metrics outside cluster (Kafka, SQS, etc.)

---

## 2. Resource Requests & Limits
- Defined at **Pod/container level**
- Used in different ways:

### Requests
- Used by **scheduler**
- Decides **which node** pod should run on

### Limits
- Enforced by **kubelet (node level)**
- CPU → throttled
- Memory → OOMKilled if exceeded

---

## 3. HPA Uses Requests (NOT Limits)
- `averageUtilization` is calculated based on **requests**
- Example:
  - CPU request = `100m`
  - Target = `50%`
  - → Target usage = `50m`

---

## 4. HPA Formula
```

desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)

```

- Runs every ~15 seconds (default)
- Uses **average across pods**

---

## 5. Multiple Metrics Behavior
- HPA calculates desired replicas for each metric separately
- Picks the **highest value**

Example:
- CPU → 2 pods
- Memory → 4 pods  
→ Final = **4 pods**

---

## 6. minReplicas & maxReplicas
- Define **hard boundaries**

```

minReplicas → minimum pods allowed
maxReplicas → maximum pods allowed

```

- Example:
  - Desired = 8, max = 5 → final = 5
  - Desired = 0, min = 1 → final = 1

---

## 7. HPA Behavior (Advanced Scaling Control)

### Purpose
- Controls **how fast scaling happens**
- Does NOT decide **when** to scale

---

## 8. Scale Up vs Scale Down

| Direction | Behavior |
|----------|--------|
| Scale Up | Fast (default) |
| Scale Down | Slow (default) |

---

## 9. Policies

### Pods Policy
```

type: Pods
value: X

```
- Add/remove fixed number of pods

### Percent Policy
```

type: Percent
value: X

```
- Scale relative to current pods

---

## 10. Percent Calculation Shortcut

### Scale Up
```

New = current × (1 + %)

```

### Scale Down
```

New = current × (1 - %)

```

Example:
- 100% of 2 → 4
- 50% of 4 → 6
- 25% of 8 → 6

---

## 11. selectPolicy

| Option | Meaning |
|--------|--------|
| Max | Pick largest scaling |
| Min | Pick smallest scaling |
| Disabled | Disable scaling |

---

## 12. periodSeconds

- Defines **time window**
- Scaling allowed within that window

### Key Concept
> HPA applies scaling in **one jump**, not step-by-step

Example:
```

4 → 6 in 15 seconds (NOT 4 → 5 → 6)

```

---

## 13. stabilizationWindowSeconds

- Prevents rapid scaling changes (flapping)

### Default
- Scale Up → 0 sec (fast)
- Scale Down → 300 sec (slow)

---

## 14. Final HPA Flow (Important)

```

1. Metrics collected
2. Desired replicas calculated (formula)
3. Apply min/max limits
4. Apply behavior policies
5. Final replicas updated

```

---

## 15. Key Mental Model

```

Metrics → decide "HOW MANY pods needed"
Behavior → decide "HOW FAST to reach that number"
min/max → define "allowed range"

```

---

## 16. Common Mistakes (You Encountered)

- ❌ Using limits instead of requests → HPA uses requests
- ❌ Wrong YAML placement of `behavior`
- ❌ Writing `pods` instead of `Pods`
- ❌ Thinking scaling happens step-by-step → it happens in jumps

---

## 🚀 One-Line Summary

> HPA scales pods based on resource usage relative to requests, calculates desired replicas using a formula, and then applies behavior rules to control how fast scaling happens within defined min/max limits.
```
