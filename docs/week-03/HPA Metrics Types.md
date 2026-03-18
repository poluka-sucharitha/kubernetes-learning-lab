# 🔥 Kubernetes HPA Metrics (autoscaling/v2)

## Overview

Horizontal Pod Autoscaler (HPA) supports **4 main metric types**:

---

## 1. Resource Metrics (Most Common)

👉 Used for: CPU & Memory

### YAML Example
```yaml
type: Resource
resource:
  name: cpu
  target:
    type: Utilization
    averageUtilization: 50
```

### ✔ Used for:
- CPU utilization
- Memory utilization

### ✔ Comes from:
- `metrics-server`

### ✔ Key Points:
- Based on **resource requests**
- Example:
  - CPU request = `100m`
  - Target = `50%`
  - → Threshold = `50m`

---

## 2. Pods Metrics (Per-Pod Custom Metrics)

👉 Measures metric **per pod**

### YAML Example
```yaml
type: Pods
pods:
  metric:
    name: requests_per_second
  target:
    type: AverageValue
    averageValue: "10"
```

### ✔ Used for:
- Requests per second per pod
- Queue length per pod
- Custom application metrics

### ✔ Comes from:
- `custom.metrics.k8s.io`

### ✔ Key Points:
- Based on **average value across pods**
- Requires **custom metrics adapter**

---

## 3. Object Metrics (Kubernetes Object Based)

👉 Metric from a **specific Kubernetes object**

### YAML Example
```yaml
type: Object
object:
  metric:
    name: requests_per_second
  describedObject:
    apiVersion: v1
    kind: Service
    name: hpa-service
  target:
    type: Value
    value: "100"
```

### ✔ Used for:
- Total traffic on a Service
- Ingress request count
- Load on a specific object

### ✔ Key Points:
- NOT per pod
- Tied to a **single Kubernetes object**
- Requires **custom metrics adapter**

---

## 4. External Metrics (Outside Kubernetes)

👉 Metrics from **external systems**

### YAML Example
```yaml
type: External
external:
  metric:
    name: queue_length
  target:
    type: Value
    value: "30"
```

### ✔ Used for:
- Kafka queue size
- AWS SQS messages
- RabbitMQ backlog
- External Prometheus data

### ✔ Comes from:
- `external.metrics.k8s.io`

### ✔ Key Points:
- Independent of pods and Kubernetes objects
- Requires **external metrics adapter**

---

# ⚡ Summary (Interview Ready)

| Type      | Source                     | Example             | Scope            |
|----------|--------------------------|--------------------|------------------|
| Resource | metrics-server           | CPU, Memory        | Per pod          |
| Pods     | custom.metrics.k8s.io    | RPS per pod        | Per pod          |
| Object   | custom.metrics.k8s.io    | Service traffic    | Single object    |
| External | external.metrics.k8s.io  | Kafka/SQS queue    | Outside cluster  |

---

# 🧠 When to Use What

- **CPU/Memory** → 80% of real-world use cases
- **Pods** → When application exposes metrics (`/metrics`)
- **Object** → For Service / Ingress-based scaling
- **External** → Event-driven systems (Kafka, SQS, queues)

---

# 🚀 Key Insight

If multiple metrics are defined:

👉 HPA chooses the **metric that requires more replicas**

Example:
- CPU → 3 pods
- Memory → 5 pods

✔ Final result → **5 pods**

---

# 📝 Notes for Practice

- Resource metrics → works out of the box
- Pods/Object/External → require:
  - Prometheus
  - Metrics adapter

👉 Practice theory now, implement later in bootcamp

