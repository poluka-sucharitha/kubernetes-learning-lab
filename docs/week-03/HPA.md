# Kubernetes Horizontal Pod Autoscaling (HPA)

---

# Overview

**Horizontal Pod Autoscaling (HPA)** in Kubernetes automatically adjusts the number of Pod replicas for a workload based on observed demand.

It commonly works with scalable resources such as:

- Deployment  
- StatefulSet  
- ReplicaSet  

It does **not** work for objects that cannot be scaled, such as:

- DaemonSet  

---

# What “Horizontal” Means

Horizontal scaling means:

- **Adding more Pods** when load increases  
- **Removing Pods** when load decreases  

This is different from **vertical scaling**, which means:

- Increasing CPU or memory for the **same existing Pod**

---

# Why HPA is Used

HPA helps you:

- Handle variable traffic automatically  
- Improve application availability under load  
- Reduce manual scaling effort  
- Save resources by scaling down when load drops  

---

# What HPA Controls

HPA is:

1. A **Kubernetes API resource**  
2. A **controller** running in the control plane  

The controller checks metrics periodically and updates the replica count of the target workload.

---

# How HPA Works

HPA works as a **control loop**.

- Runs periodically (default **15 seconds**)  
- Controlled by:

```text
--horizontal-pod-autoscaler-sync-period
Flow

Reads target from scaleTargetRef

Selects Pods using labels

Fetches metrics

Compares current vs desired

Decides scale up/down

Common Metrics Used by HPA

CPU utilization

Memory utilization

Custom metrics

External metrics

Container metrics

Multiple metrics

Metrics Sources

metrics.k8s.io → CPU/Memory

custom.metrics.k8s.io

external.metrics.k8s.io

Required Components

Metrics Server

Metrics adapters

HPA Scaling Formula
desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)
Example (Scale Up)

current = 2

CPU = 200m

target = 100m

2 × (200/100) = 4

➡️ Pods: 2 → 4

Example (Scale Down)

current = 4

CPU = 50m

target = 100m

4 × (50/100) = 2

➡️ Pods: 4 → 2

Tolerance (VERY IMPORTANT)

Default tolerance = 10%

HPA checks:

ratio = current / desired

If:

0.9 < ratio < 1.1 → NO scaling
Key Idea

Formula → calculates replicas

Tolerance → decides whether to scale

Requirement for CPU/Memory HPA

You MUST define:

resources:
  requests:
    cpu: "200m"
    memory: "256Mi"

Otherwise:

HPA cannot calculate utilization properly

Example HPA
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
Container Resource Metrics

Scale based on specific container:

type: ContainerResource
containerResource:
  name: cpu
  container: application
  target:
    type: Utilization
    averageUtilization: 60
Custom & External Metrics

Examples:

Requests/sec

Queue size

External system load

Multiple Metrics

HPA:

Calculates replicas for each metric

Chooses highest value

Pod Readiness & HPA

HPA considers:

Only Ready pods

Ignores:

Failed pods

Deleting pods

Startup Problem

Apps may show high CPU at startup.

If not handled:

❌ HPA over-scales

Solution

Use:

startupProbe:
readinessProbe:
HPA Startup Settings
CPU Initialization Period
--horizontal-pod-autoscaler-cpu-initialization-period (5 min)
Initial Readiness Delay
--horizontal-pod-autoscaler-initial-readiness-delay (30 sec)
Missing Metrics Handling

If metrics missing:

Scale DOWN → assume 100% usage

Scale UP → assume 0% usage

Stabilization (VERY IMPORTANT)

Prevents:

Flapping

Frequent scaling

Downscale Stabilization Window

Default:

5 minutes

Behavior:

➡️ HPA remembers past recommendations
➡️ Picks highest value
➡️ Delays scaling down

Scaling Behavior (autoscaling/v2)
behavior:
Scaling Policies

Control speed of scaling.

Example (Scale Down)
behavior:
  scaleDown:
    policies:
    - type: Percent
      value: 10
      periodSeconds: 60
    - type: Pods
      value: 5
      periodSeconds: 60
    selectPolicy: Min
Meaning

Remove 10% OR 5 pods

Choose smaller (Min)

Combined Behavior (VERY IMPORTANT)
1. Stabilization → WHEN to scale
2. Policies → HOW MUCH to scale
Real Flow

Initial pods = 10

Metrics drop:

Wait 5 min (stabilization)

Then:

10 → 9 → 8 → 7 → 6

NOT:

10 → 6 ❌
Key Understanding
Component	Role
Stabilization	delay
Policies	speed
selectPolicy	safety
Scale Up Behavior
scaleUp:
  stabilizationWindowSeconds: 0
  policies:
  - type: Percent
    value: 100
  - type: Pods
    value: 4
  selectPolicy: Max
Meaning

Scale immediately

Either:

double pods

or add 4 pods

Choose larger

Scale Up vs Scale Down
Type	Behavior
Scale Up	Fast 🚀
Scale Down	Slow 🧠
Rolling Updates + HPA

HPA → controls Deployment

Deployment → controls ReplicaSet

ReplicaSet → controls Pods

Important Rule

Remove:

spec:
  replicas:

Otherwise:

❌ Conflicts with HPA

kubectl Commands
kubectl get hpa
kubectl describe hpa
kubectl delete hpa <name>
kubectl autoscale deployment my-app --min=2 --max=5 --cpu-percent=80
End-to-End Flow
Metrics → HPA → Deployment → ReplicaSet → Pods
Best Practices

Set resource requests

Install Metrics Server

Use autoscaling/v2

Configure probes

Avoid flapping

Remove static replicas

Set proper min/max

Limitations

Needs metrics APIs

CPU requires requests

Not continuous (runs every 15s)

Not for DaemonSet

Short Summary

HPA:

Auto scales Pods

Uses metrics

Prevents overload

Saves resources

Supports advanced tuning

Interview Key Points

HPA = auto scaling of Pods

Uses CPU, memory, custom metrics

Default sync = 15s

Uses formula + tolerance

Multiple metrics → max wins

Stabilization prevents flapping

Minimal Example
Deployment
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
HPA
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
One-Line Revision

HPA = auto Pod scaling

Horizontal = more pods

Vertical = more resources

Needs metrics + requests

Uses formula + tolerance

Scale up fast, down slow

Stabilization avoids flapping