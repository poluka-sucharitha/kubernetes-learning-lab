````md
# Kubernetes Horizontal Pod Autoscaling (HPA)

## Overview

**Horizontal Pod Autoscaling (HPA)** in Kubernetes automatically adjusts the number of Pod replicas for a workload based on observed demand.

It commonly works with scalable resources such as:

- Deployment
- StatefulSet
- ReplicaSet

It does **not** work for objects that cannot be scaled, such as:

- DaemonSet

---

## What “Horizontal” Means

Horizontal scaling means:

- **Adding more Pods** when load increases
- **Removing Pods** when load decreases

This is different from **vertical scaling**, which means:

- Increasing CPU or memory for the **same existing Pod**

---

## Why HPA is Used

HPA helps you:

- Handle variable traffic automatically
- Improve application availability under load
- Reduce manual scaling effort
- Save resources by scaling down when load drops

---

## What HPA Controls

HPA is:

1. A **Kubernetes API resource**
2. A **controller** running in the control plane

The controller checks metrics periodically and updates the replica count of the target workload.

---

## How HPA Works

HPA works as a **control loop**.

- The controller checks metrics at regular intervals
- Default sync period is **15 seconds**
- This interval is controlled by:

```text
--horizontal-pod-autoscaler-sync-period
````

During each cycle, Kubernetes:

* Reads the target workload from `scaleTargetRef`
* Finds the Pods belonging to that workload using label selectors
* Fetches metrics
* Compares current metric values with desired target values
* Decides whether to scale up, scale down, or do nothing

---

## Common Metrics Used by HPA

HPA can scale based on:

* CPU utilization
* Memory utilization
* Custom metrics
* External metrics
* Container-specific resource metrics
* Multiple metrics together

---

## Metrics Sources Used by HPA

HPA reads metrics from aggregated APIs such as:

* `metrics.k8s.io`
* `custom.metrics.k8s.io`
* `external.metrics.k8s.io`

### Usually required components

* Metrics Server (for CPU and memory)
* Custom metrics adapter (for custom or external metrics)

---

## HPA Scaling Formula

At a basic level, HPA calculates desired replicas using this formula:

```text
desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)
```

### Example 1: Scale Up

* Current replicas = 2
* Current CPU = 200m
* Desired CPU = 100m

```text
desiredReplicas = ceil(2 × 200 / 100)
                = ceil(4)
                = 4
```

Kubernetes scales from 2 Pods to 4 Pods.

---

### Example 2: Scale Down

* Current replicas = 4
* Current CPU = 50m
* Desired CPU = 100m

```text
desiredReplicas = ceil(4 × 50 / 100)
                = ceil(2)
                = 2
```

Kubernetes scales from 4 Pods to 2 Pods.

---

## Tolerance

HPA does not scale for tiny fluctuations near the target.

* Default tolerance: **10% (0.1)**

This avoids unnecessary scaling caused by small metric changes.

---

## Important Requirement for CPU/Memory Based HPA

For HPA to work correctly with CPU or memory utilization:

**Resource requests must be set**

```yaml
resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
```

Without resource requests:

* CPU utilization cannot be calculated properly
* HPA may not take action

---

## Example HPA Using CPU

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

### Meaning

* Target workload: `my-app` Deployment
* Minimum Pods: 2
* Maximum Pods: 10
* Maintain ~60% average CPU usage

---

## Resource Metrics (CPU/Memory)

```yaml
type: Resource
resource:
  name: cpu
  target:
    type: Utilization
    averageUtilization: 60
```

* HPA keeps average CPU utilization at 60% across Pods
* Pod-level usage = sum of all container usage in the Pod

⚠️ One overloaded container may be hidden if others are idle.

---

## Container Resource Metrics

```yaml
type: ContainerResource
containerResource:
  name: cpu
  container: application
  target:
    type: Utilization
    averageUtilization: 60
```

* Tracks only the specified container
* Ignores sidecars

---

## Scaling on Custom Metrics

Examples:

* Requests per second
* Queue length
* Active sessions

Requires:

* `autoscaling/v2`
* Custom metrics API
* Metrics adapter

---

## Scaling on External Metrics

Examples:

* Cloud queue size
* Third-party monitoring data

Requires:

* `external.metrics.k8s.io`
* External metrics adapter

---

## Scaling on Multiple Metrics

HPA:

* Calculates desired replicas for each metric
* Chooses the **highest** value

---

## Pod Readiness and HPA

HPA ignores or handles carefully:

* Failed Pods
* Deleting Pods
* Not Ready Pods
* Pods with missing metrics

---

## Startup Behavior

New Pods often show temporary spikes:

* JVM warm-up
* Cache loading
* Initialization

### HPA avoids reacting too early

---

### Key Settings

#### CPU Initialization Period

* Default: **5 minutes**
* Ignores early CPU spikes

#### Initial Readiness Delay

* Default: **30 seconds**
* Treats unstable Pods as initializing

---

### Best Practices

* Use `startupProbe`
* Use `readinessProbe`
* Set proper delays

---

## Missing Metrics Handling

* During **scale down** → assume 100% usage
* During **scale up** → assume 0% usage

---

## Stabilization (Avoid Flapping)

### Downscale Stabilization Window

* Default: **5 minutes**

```text
--horizontal-pod-autoscaler-downscale-stabilization
```

Prevents rapid scale down.

---

## Configurable Scaling Behavior

```yaml
behavior:
```

### Example

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

---

### selectPolicy Options

* `Max` → largest change
* `Min` → smallest change
* `Disabled` → disable scaling

---

### Example: Conservative Scale Down

```yaml
selectPolicy: Min
```

---

### Example: Disable Scale Down

```yaml
behavior:
  scaleDown:
    selectPolicy: Disabled
```

---

### Custom Stabilization Window

```yaml
stabilizationWindowSeconds: 60
```

---

### Tolerance Example

```yaml
scaleUp:
  tolerance: 0.05
```

---

## Default Behavior (Simplified)

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300
  scaleUp:
    stabilizationWindowSeconds: 0
```

* Fast scale up
* Slow scale down

---

## HPA During Rolling Updates

* HPA updates Deployment replicas
* Deployment distributes Pods across ReplicaSets

Hierarchy:

```text
HPA → Deployment → ReplicaSet → Pods
```

---

## Supported Workloads

Supported:

* Deployment
* StatefulSet
* ReplicaSet

Not supported:

* DaemonSet

---

## Maintenance Mode

If:

* Replicas manually set to 0

HPA effectively pauses.

---

## Important: Avoid `spec.replicas`

Remove from Deployment manifest when using HPA:

```yaml
spec:
  replicas:
```

Otherwise:

* `kubectl apply` may override HPA decisions

---

## kubectl Commands

```bash
kubectl apply -f hpa.yaml
kubectl get hpa
kubectl describe hpa
kubectl delete hpa <name>
```

---

### Quick Creation

```bash
kubectl autoscale rs foo --min=2 --max=5 --cpu-percent=80
```

---

## End-to-End Flow

1. Application runs in Pods
2. Metrics Server provides metrics
3. HPA reads metrics
4. HPA calculates desired replicas
5. Workload replica count updated
6. Pods added/removed

---

## Real-World Example

* minReplicas: 2
* maxReplicas: 10
* CPU target: 60%

### High Load

* CPU → 85%
* Scale up (e.g., 2 → 4)

### Low Load

* CPU → 20%
* Gradual scale down

---

## Best Practices

1. Set resource requests
2. Install Metrics Server
3. Use `autoscaling/v2`
4. Configure probes properly
5. Avoid flapping
6. Remove static replicas
7. Set sensible min/max

---

## Limitations

* Requires metrics APIs
* CPU scaling needs requests
* Not continuous (periodic loop)
* Missing metrics affect decisions
* Pod averages can hide container issues
* Does not support DaemonSet

---

## Short Summary

* HPA = automatic Pod scaling
* Horizontal = add/remove Pods
* Uses CPU, memory, custom, external metrics
* Requires metrics + resource requests
* Prevents flapping with stabilization

---

## Interview Key Points

**What is HPA?**
Automatically scales Pods based on metrics.

**What metrics are supported?**
CPU, memory, custom, external, container, multi-metric.

**Why CPU requests matter?**
Utilization is based on requested CPU.

**Does HPA run continuously?**
No, every ~15 seconds.

**Does it support DaemonSet?**
No.

**Multiple metrics behavior?**
Chooses highest replica count.

---

## Minimal Example

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

---

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

## One-Line Revision Notes

* HPA = automatic Pod scaling
* Horizontal = more/fewer Pods
* Vertical = bigger Pods
* Works on Deployment/StatefulSet
* Needs metrics
* CPU scaling requires requests
* Sync period = 15s
* Uses scaling formula
* Supports multiple metrics
* Prevents flapping
* Use `autoscaling/v2`

```
```
