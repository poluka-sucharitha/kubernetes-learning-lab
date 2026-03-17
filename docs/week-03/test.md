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

During each cycle, Kubernetes:

Reads the target workload from scaleTargetRef

Finds the Pods belonging to that workload using label selectors

Fetches metrics

Compares current metric values with desired target values

Decides whether to scale up, scale down, or do nothing

Common Metrics Used by HPA

HPA can scale based on:

CPU utilization

Memory utilization

Custom metrics

External metrics

Container-specific resource metrics

Multiple metrics together

Metrics Sources Used by HPA

HPA reads metrics from aggregated APIs such as:

metrics.k8s.io

custom.metrics.k8s.io

external.metrics.k8s.io

Usually required components

Metrics Server for CPU and memory

Custom metrics adapter for custom or external metrics

HPA Scaling Formula

At a basic level, HPA calculates desired replicas using this formula:

desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)
Example 1: Scale Up

Current replicas = 2

Current CPU = 200m

Desired CPU = 100m

desiredReplicas = ceil(2 × 200 / 100)
                = ceil(4)
                = 4

So Kubernetes scales from 2 Pods to 4 Pods.

Example 2: Scale Down

Current replicas = 4

Current CPU = 50m

Desired CPU = 100m

desiredReplicas = ceil(4 × 50 / 100)
                = ceil(2)
                = 2

So Kubernetes scales from 4 Pods to 2 Pods.

Tolerance

HPA does not scale for tiny fluctuations near the target.

By default, scaling is skipped if the ratio is close enough to 1.0.

Default tolerance is generally:

10% (0.1)

This avoids unnecessary scaling caused by small metric changes.

Important Requirement for CPU/Memory Based HPA

For HPA to work correctly with CPU or memory utilization:

Resource requests must be set

Example:

resources:
  requests:
    cpu: "200m"
    memory: "256Mi"

Without resource requests:

CPU utilization cannot be calculated properly

HPA may not take action for that metric

Example HPA Using CPU
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
Meaning

Target workload: my-app Deployment

Minimum Pods: 2

Maximum Pods: 10

Keep average CPU usage around 60%

Resource Metrics
CPU or Memory Based Scaling

Example metric:

type: Resource
resource:
  name: cpu
  target:
    type: Utilization
    averageUtilization: 60

This means:

HPA tries to keep average CPU utilization at 60% across all Pods

Important note

Pod-level utilization is calculated using the sum of resource usage across containers in that Pod.

So if one container is overloaded but others are idle, the overall Pod average may hide that issue.

Container Resource Metrics

Kubernetes also supports scaling using a specific container’s resource usage.

This is useful when:

A Pod has multiple containers

Only one container is important for scaling

You want to ignore sidecars like logging or monitoring containers

Example
type: ContainerResource
containerResource:
  name: cpu
  container: application
  target:
    type: Utilization
    averageUtilization: 60

This means:

Track only the application container CPU usage

Ignore other containers in the Pod

Scaling on Custom Metrics

You can scale based on application-specific metrics, such as:

Requests per second

Queue length

Active sessions

Business-specific counters

Example idea:

Scale when requests per second exceed a threshold

This requires:

autoscaling/v2

Custom metrics API support

Metrics adapter

Scaling on External Metrics

HPA can scale based on metrics outside the cluster, such as:

Cloud queue size

External monitoring metric

Third-party service measurements

This requires:

external.metrics.k8s.io

Suitable external metrics adapter

Scaling on Multiple Metrics

HPA can use multiple metrics at the same time.

Example:

CPU utilization

Memory utilization

Queue length

Kubernetes calculates desired replicas for each metric and then chooses:

the highest recommended replica count

This ensures the application scales according to whichever metric indicates the greatest demand.

Pod Readiness and HPA

HPA does not blindly use every Pod metric.

It handles Pods carefully when:

Metrics are missing

Pods are not Ready

Pods are still starting up

Pods are being deleted

Pods have failed

Pods ignored by HPA

HPA ignores:

Pods being deleted

Failed Pods

Pods set aside temporarily

HPA may set aside:

Pods with missing metrics

Pods that are not yet Ready

Pods still initializing

This helps avoid wrong scaling decisions.

Why Startup Behavior Matters

New Pods often show unusual CPU usage during startup.

Examples:

Java warm-up

Cache loading

Dependency initialization

Framework bootstrap

If HPA used these startup spikes immediately, it could incorrectly scale too much.

HPA Startup-Related Settings
1. CPU Initialization Period
--horizontal-pod-autoscaler-cpu-initialization-period

Default:

5 minutes

Purpose:

Ignore CPU metrics from recently started Pods unless they were properly Ready during the metric collection window

2. Initial Readiness Delay
--horizontal-pod-autoscaler-initial-readiness-delay

Default:

30 seconds

Purpose:

Treat Pods that briefly toggle Ready/Unready during startup as still initializing

Avoid unstable startup metrics influencing HPA too early

Good Practices for Startup + HPA

To avoid bad scaling decisions during startup:

Use a startupProbe

Use a proper readinessProbe

Set realistic initialDelaySeconds

Ensure the app becomes Ready only after startup spikes are over

This helps HPA use cleaner and more reliable metrics.

Missing Metrics Handling

If some Pods do not have metrics available:

HPA behaves conservatively

During scale down

It may assume missing Pods are consuming 100% of the desired value

During scale up

It may assume missing Pods are consuming 0% of the desired value

This prevents overly aggressive scaling decisions.

Not-Yet-Ready Pods Handling

If some Pods are not yet Ready and scaling would have gone upward:

HPA may assume those Pods use 0% of desired metrics

This reduces aggressive scale-up during unstable startup conditions

Stabilization Against Flapping

Applications with dynamic traffic may constantly scale up and down.

This is called:

Flapping

Thrashing

HPA reduces this problem using stabilization logic.

Downscale Stabilization Window

Before scaling down, HPA remembers earlier scaling recommendations and chooses the highest one within a time window.

Default downscale stabilization window:

5 minutes

Controlled by:

--horizontal-pod-autoscaler-downscale-stabilization

This makes scale down more gradual and stable.

Configurable Scaling Behavior

Using autoscaling/v2, you can customize HPA behavior.

You can separately configure:

scaleUp

scaleDown

These settings are defined under:

behavior:
Scaling Policies

Scaling policies control how fast HPA can change the number of replicas.

Example:

behavior:
  scaleDown:
    policies:
    - type: Pods
      value: 4
      periodSeconds: 60
    - type: Percent
      value: 10
      periodSeconds: 60
Meaning

Within 60 seconds, HPA may reduce replicas by either:

4 Pods

10%

By default, HPA chooses the policy that allows the largest change.

selectPolicy

You can choose which policy is preferred.

Possible values:

Max → use the policy allowing the largest change

Min → use the policy allowing the smallest change

Disabled → disable scaling in that direction

Example: Limit Scale Down
behavior:
  scaleDown:
    policies:
    - type: Percent
      value: 10
      periodSeconds: 60

Meaning:

HPA can reduce only 10% of replicas per minute

Example: No More Than 5 Pods Down Per Minute
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

Meaning:

HPA applies the most conservative rule

It will choose the policy that removes fewer Pods

Example: Disable Scale Down
behavior:
  scaleDown:
    selectPolicy: Disabled

Meaning:

HPA will not reduce Pods

It can still scale up if allowed

Example: Custom Downscale Stabilization Window
behavior:
  scaleDown:
    stabilizationWindowSeconds: 60

Meaning:

Wait more carefully before scaling down

Use past recommendations from the last 60 seconds

Tolerance in Behavior

HPA also supports configurable tolerance to ignore very small metric changes.

Example:

behavior:
  scaleUp:
    tolerance: 0.05

Meaning:

Scale up only if usage exceeds the target by more than 5%

Default HPA Behavior

Default-like behavior generally looks like this:

behavior:
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
    - type: Pods
      value: 4
      periodSeconds: 15
    selectPolicy: Max
Interpretation

Scale up can happen quickly

Scale down is stabilized

HPA can add Pods fast when needed

HPA reduces Pods more carefully

HPA During Rolling Updates

When HPA is attached to a Deployment:

HPA updates the Deployment replica count

The Deployment controller distributes replicas across ReplicaSets during rollout

So:

HPA manages the Deployment

Deployment manages ReplicaSets

ReplicaSets manage Pods

For StatefulSet:

StatefulSet directly manages the Pods

HPA and Workloads

HPA works with workloads that support the scale subresource, such as:

Deployment

StatefulSet

ReplicaSet

It does not apply to workloads that do not support scaling, such as:

DaemonSet

Maintenance Mode / Implicit Deactivation

HPA can be effectively paused without deleting it.

If:

Target replicas are manually set to 0

HPA minimum replicas are greater than 0

Then HPA stops actively adjusting until it is reactivated.

Important When Using HPA with Deployments

If HPA is managing a Deployment, it is recommended to remove:

spec:
  replicas:

from the Deployment manifest.

Why?

Because if spec.replicas remains in the manifest and you run:

kubectl apply -f deployment.yaml

Kubernetes may reset the replica count to that static value, fighting with the HPA.

This can cause:

unexpected scale resets

flapping

thrashing

kubectl Commands for HPA
Create HPA manually with YAML
kubectl apply -f hpa.yaml
List HPAs
kubectl get hpa
Describe HPA
kubectl describe hpa
Delete HPA
kubectl delete hpa <name>
Quick HPA Creation with kubectl autoscale

Example:

kubectl autoscale rs foo --min=2 --max=5 --cpu-percent=80

Meaning:

Target: ReplicaSet foo

Min replicas: 2

Max replicas: 5

Scale based on 80% CPU utilization

End-to-End Flow of HPA

Application runs in Pods

Metrics Server or adapter provides metrics

HPA controller reads metrics

HPA compares current metric vs desired target

HPA calculates desired replicas

Deployment/StatefulSet replica count is updated

Kubernetes adds or removes Pods

Real-World Example

Suppose you have a web app Deployment with:

minReplicas: 2

maxReplicas: 10

target CPU: 60%

Situation 1: Traffic increases

CPU rises to 85%

HPA computes more replicas needed

Pods increase from 2 to 4 or more

Situation 2: Traffic decreases

CPU drops to 20%

HPA waits according to scale-down behavior

Pods gradually reduce, but not below minReplicas

Best Practices for HPA
1. Always set resource requests

Without CPU/memory requests, resource-based HPA may not work properly.

2. Install Metrics Server

Without it, CPU and memory metrics will not be available.

3. Use autoscaling/v2

This version supports:

multiple metrics

memory metrics

behavior customization

custom and external metrics

container resource metrics

4. Configure readiness and startup properly

Use:

startupProbe

readinessProbe

realistic delays

This prevents startup CPU spikes from misleading HPA.

5. Avoid aggressive flapping

Set:

stabilization windows

scale policies

tolerance

6. Remove static replicas from manifests

When HPA manages replicas, avoid hardcoding spec.replicas in repeatedly applied manifests.

7. Choose sensible min and max values

Example:

Too low minReplicas may hurt availability

Too high maxReplicas may waste resources

Limitations / Things to Remember

HPA needs metrics APIs to function

CPU scaling needs resource requests

HPA reacts periodically, not continuously

Missing metrics can affect scaling decisions

One overloaded container may be hidden in whole-Pod averages unless container metrics are used

HPA does not scale DaemonSets

Short Summary

Horizontal Pod Autoscaler:

Automatically increases or decreases Pod count

Uses metrics such as CPU, memory, custom, or external metrics

Helps match application capacity with demand

Requires proper metrics setup and resource requests

Supports advanced behavior tuning to avoid flapping

Interview-Style Key Points
What is HPA?

HPA is a Kubernetes resource and controller that automatically scales the number of Pod replicas for a workload based on observed metrics.

What metrics can HPA use?

CPU

Memory

Custom metrics

External metrics

Container-specific metrics

Multiple metrics together

Why are CPU requests important for HPA?

Because CPU utilization is calculated relative to requested CPU. Without requests, utilization-based scaling cannot work correctly.

Does HPA scale continuously?

No. It runs as a periodic control loop, usually every 15 seconds.

Can HPA work on DaemonSet?

No. DaemonSet is not horizontally scalable in the HPA sense.

How does HPA avoid flapping?

By using:

tolerance

stabilization window

scaling policies

If multiple metrics are defined, which one wins?

HPA chooses the largest desired replica count among the metrics.

Minimal Example Set
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
One-Line Revision Notes

HPA = automatic Pod scaling

Horizontal = more or fewer Pods

Vertical = more CPU/memory in same Pod

Works on Deployment/StatefulSet/ReplicaSet

Needs metrics

CPU scaling needs resource requests

Default sync period = 15s

Uses formula based on current vs desired metric

Supports CPU, memory, custom, external, multi-metric

Stabilization prevents flapping

autoscaling/v2 is preferred