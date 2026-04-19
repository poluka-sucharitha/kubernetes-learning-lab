# Kubernetes Horizontal Pod Autoscaling (HPA)

## Overview

**Horizontal Pod Autoscaling (HPA)** automatically adjusts the number of Pod replicas for a workload based on observed demand.

Works with scalable resources:
- Deployment
- StatefulSet
- ReplicaSet

Does **not** work with:
- DaemonSet (every node runs exactly one pod — can't be scaled horizontally)

---

## What "Horizontal" Means

| Scaling Type | What it does |
|---|---|
| **Horizontal** | Adds or removes **Pods** |
| **Vertical** | Increases CPU/memory of the **same Pod** |

---

## Why HPA is Used

- Handle variable traffic automatically
- Improve availability under load
- Reduce manual scaling effort
- Save resources by scaling down when load drops

---

## What HPA Controls

HPA is both:
1. A **Kubernetes API resource** (`kind: HorizontalPodAutoscaler`)
2. A **controller** running in the control plane

The controller checks metrics periodically and updates the replica count of the target workload.

---

## How HPA Works

HPA works as a **control loop**:

- Checks metrics at regular intervals
- Default sync period: **15 seconds**
- Controlled by flag: `--horizontal-pod-autoscaler-sync-period`

During each cycle, Kubernetes:

```
1. Reads target workload from scaleTargetRef
2. Finds Pods using label selectors
3. Fetches current metrics
4. Compares current vs desired metric values
5. Decides → scale up / scale down / do nothing
```

---

## Common Metrics Used by HPA

- CPU utilization
- Memory utilization
- Custom metrics (requests/sec, queue length)
- External metrics (cloud queue size, third-party data)
- Container-specific resource metrics
- Multiple metrics together

---

## Metrics Sources

| API | Used For |
|---|---|
| `metrics.k8s.io` | CPU and memory |
| `custom.metrics.k8s.io` | Custom metrics |
| `external.metrics.k8s.io` | External metrics |

**Required components:**
- **Metrics Server** — for CPU and memory
- **Custom metrics adapter** — for custom or external metrics

---

## HPA Scaling Formula

```
desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)
```

### Example 1 — Scale Up

```
Current replicas = 2
Current CPU      = 200m
Desired CPU      = 100m

desiredReplicas = ceil(2 × 200 / 100)
               = ceil(4)
               = 4  ← scales from 2 → 4 Pods
```

### Example 2 — Scale Down

```
Current replicas = 4
Current CPU      = 50m
Desired CPU      = 100m

desiredReplicas = ceil(4 × 50 / 100)
               = ceil(2)
               = 2  ← scales from 4 → 2 Pods
```

---

## Tolerance

HPA does **not** scale for tiny fluctuations near the target.

- Default tolerance: **10% (0.1)**

> Avoids unnecessary scaling caused by small metric changes.

---

## Important — Resource Requests Must Be Set

For CPU/memory based HPA to work:

```yaml
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
```

Without resource requests:
- CPU utilization cannot be calculated
- HPA will not take action

> **Even without HPA, resource requests and limits are CRITICAL for proper scheduling, preventing node overload, fair resource sharing, and cluster stability.**

---

## Example HPA — CPU Based

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

| Field | Meaning |
|---|---|
| `scaleTargetRef` | Target workload to scale |
| `minReplicas` | Minimum 2 Pods always running |
| `maxReplicas` | Never exceed 10 Pods |
| `averageUtilization: 60` | Keep average CPU at ~60% |

---

## Metric Types

### Resource Metrics (Pod-level CPU/Memory)

```yaml
type: Resource
resource:
  name: cpu
  target:
    type: Utilization
    averageUtilization: 60
```

> ⚠️ One overloaded container may be hidden if other containers in the same Pod are idle.

---

### Container Resource Metrics

```yaml
type: ContainerResource
containerResource:
  name: cpu
  container: application
  target:
    type: Utilization
    averageUtilization: 60
```

> Tracks only the specified container — ignores sidecars.

---

### Custom Metrics

Examples: requests per second, queue length, active sessions

Requires:
- `autoscaling/v2`
- Custom metrics API + adapter

---

### External Metrics

Examples: Cloud queue size, third-party monitoring data

Requires:
- `external.metrics.k8s.io`
- External metrics adapter

---

### Multiple Metrics

HPA calculates desired replicas for **each metric separately** and chooses the **highest** value.

---

## Pod Readiness and HPA

HPA carefully handles or ignores:
- Failed Pods
- Deleting Pods
- Not Ready Pods
- Pods with missing metrics

---

## Startup Behavior

New Pods often show temporary spikes during:
- JVM warm-up
- Cache loading
- Initialization

HPA avoids reacting too early using:

| Setting | Default | Purpose |
|---|---|---|
| CPU Initialization Period | **5 minutes** | Ignores early CPU spikes |
| Initial Readiness Delay | **30 seconds** | Treats unstable Pods as initializing |

**Best practices:**
- Use `startupProbe`
- Use `readinessProbe`
- Set proper delays

---

## Missing Metrics Handling

| Situation | HPA Assumes |
|---|---|
| Scale down | 100% usage (conservative — holds back) |
| Scale up | 0% usage (conservative — holds back) |

---

## Stabilization — Avoiding Flapping

### Downscale Stabilization Window

- Default: **5 minutes**
- Prevents rapid repeated scale-down

```
--horizontal-pod-autoscaler-downscale-stabilization
```

### Default Behavior

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300   # slow scale down
  scaleUp:
    stabilizationWindowSeconds: 0     # fast scale up
```

> **Fast scale up. Slow scale down.** — intentional design to protect availability.

---

## Configurable Scaling Behavior

```yaml
behavior:
  scaleDown:
    policies:
    - type: Pods
      value: 4
      periodSeconds: 60
    - type: Percent
      value: 10
      periodSeconds: 60
```

### selectPolicy Options

| Value | Behavior |
|---|---|
| `Max` | Apply largest change |
| `Min` | Apply smallest change (conservative) |
| `Disabled` | Disable scaling in that direction |

### Example — Conservative Scale Down

```yaml
selectPolicy: Min
```

### Example — Disable Scale Down

```yaml
behavior:
  scaleDown:
    selectPolicy: Disabled
```

### Custom Stabilization Window

```yaml
stabilizationWindowSeconds: 60
```

### Custom Tolerance

```yaml
scaleUp:
  tolerance: 0.05
```

---

## HPA During Rolling Updates

```
HPA → Deployment → ReplicaSet → Pods
```

HPA updates Deployment replicas. Deployment distributes Pods across ReplicaSets during rolling updates.

---

## Maintenance Mode

Setting replicas manually to `0` effectively **pauses HPA**.

---

## Important — Avoid `spec.replicas` in Deployment Manifest

When using HPA, remove this from your Deployment:

```yaml
spec:
  replicas:   # ← remove this
```

If kept, `kubectl apply` may **override HPA decisions** on every apply.

---

## kubectl Commands

```bash
# Apply HPA from file
kubectl apply -f hpa.yaml

# List all HPAs
kubectl get hpa

# Describe HPA (shows current metrics and replica decisions)
kubectl describe hpa

# Delete HPA
kubectl delete hpa <name>

# Quick creation via CLI
kubectl autoscale rs foo --min=2 --max=5 --cpu-percent=80
```

---

## End-to-End Flow

```
1. Application runs in Pods
2. Metrics Server collects metrics
3. HPA reads metrics every 15s
4. HPA calculates desired replicas (formula)
5. Workload replica count updated
6. Pods added or removed
```

Full internal chain:

```
HPA (controller)
    ↓
Updates Deployment replicas
    ↓
ReplicaSet creates/removes Pods
    ↓
Scheduler assigns Pods to nodes
    ↓
Kubelet runs containers
```

---

## Real-World Example

```
minReplicas: 2   maxReplicas: 10   CPU target: 60%

High load → CPU 85% → scale up   (2 → 4 Pods)
Low load  → CPU 20% → gradual scale down (4 → 2 Pods)
```

---

## Minimal Working Example

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: k8s.gcr.io/hpa-example
        resources:
          requests:
            cpu: 200m
```

### HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

---

## Best Practices

1. Always set **resource requests** on containers
2. Install **Metrics Server** before using HPA
3. Use `autoscaling/v2` (not v1)
4. Configure `startupProbe` and `readinessProbe`
5. Avoid flapping — tune stabilization windows
6. Remove `spec.replicas` from Deployment manifest
7. Set sensible `minReplicas` and `maxReplicas`

---

## Limitations

- Requires metrics APIs to be available
- CPU scaling requires resource requests
- Not continuous — runs every ~15 seconds
- Missing metrics affect scaling decisions
- Pod-level averages can hide per-container issues
- Does not support DaemonSet

---

## Interview Key Points

| Question | Answer |
|---|---|
| What is HPA? | Automatically scales Pods based on metrics |
| What metrics are supported? | CPU, memory, custom, external, container, multi-metric |
| Why do CPU requests matter? | Utilization % is calculated against requested CPU |
| Does HPA run continuously? | No — every ~15 seconds |
| Does it support DaemonSet? | No |
| Multiple metrics behavior? | Chooses highest desired replica count |

---

## One-Line Revision Notes

- HPA = automatic Pod scaling
- Horizontal = more/fewer Pods | Vertical = bigger Pods
- Works on Deployment / StatefulSet / ReplicaSet
- Needs Metrics Server installed
- CPU scaling requires resource requests
- Sync period = 15 seconds
- Formula: `ceil(currentReplicas × currentMetric / targetMetric)`
- Multiple metrics → highest replica count wins
- Prevents flapping via stabilization windows
- Always use `autoscaling/v2`
- Remove `spec.replicas` from Deployment when using HPA
