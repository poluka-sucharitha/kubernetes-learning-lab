# 📘 KEDA, HPA, Triggers, Scalers & CRDs — Complete Learning Notes

This document is a consolidated and rephrased set of notes based on the full discussion. It is meant for revision and GitHub reference.

It covers:

- HPA basics
- Resource requests and limits
- Why HPA uses requests
- HPA metric types
- HPA scaling formula
- Multi-metric behavior
- KEDA basics
- Why KEDA is needed
- HPA without KEDA
- KEDA with HPA
- ScaledObject meaning
- Trigger vs Scaler
- CRD meaning and purpose
- Why CRDs are required
- What happens without CRDs
- CRD + Controller concept
- Java heap/log scaling discussion
- KEDA-related commands
- Key clarifications from the conversation

---

# 1. Horizontal Pod Autoscaler (HPA)

## What is HPA?

**HPA (Horizontal Pod Autoscaler)** is a native Kubernetes resource that automatically increases or decreases the number of pod replicas based on observed metrics.

It commonly works with scalable resources such as:

- Deployment
- StatefulSet
- ReplicaSet

It does **not** directly scale resources like:

- DaemonSet

---

## What “horizontal” means

Horizontal scaling means:

- adding more pods when load increases
- removing pods when load decreases

This is different from **vertical scaling**, which means increasing CPU or memory for the same existing pod.

---

## Why HPA is used

HPA helps in:

- handling changing traffic automatically
- improving availability during increased load
- reducing manual scaling work
- saving resources when traffic decreases

---

## What HPA controls

HPA is:

1. a Kubernetes API resource
2. a controller-based mechanism in the control plane

The HPA controller runs in a loop, checks metrics, compares current values with desired values, and updates the target workload replica count.

---

# 2. Resource Requests and Limits

You asked an important question about why requests and limits matter, even beyond HPA.

## Requests

**Requests** are the guaranteed minimum resources a container asks for.

Example:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

Requests are mainly used by the **scheduler**.

That means Kubernetes uses requests to decide:

- on which node the pod can be placed
- whether that node has enough available CPU and memory

---

## Limits

**Limits** define the maximum resources a container is allowed to consume.

Example:

```yaml
resources:
  limits:
    cpu: 200m
    memory: 256Mi
```

Limits are enforced by the **kubelet/container runtime** on the node.

Behavior:

- CPU over limit → throttling
- Memory over limit → container may be killed with OOMKilled

---

## Why requests and limits matter even without HPA

Even if you do not use HPA, requests and limits are still important.

### Requests help with:

- proper pod scheduling
- avoiding overcommit confusion
- reserving a minimum amount of CPU and memory

### Limits help with:

- preventing one container from consuming too many resources
- isolating noisy workloads
- protecting the node and other applications

So requests and limits are useful **even without autoscaling**.

---

# 3. HPA Uses Requests, Not Limits

This was one of the most important clarified points.

When HPA uses:

```yaml
averageUtilization: 50
```

for CPU or memory resource metrics, the percentage is calculated against the **resource request**, not the limit.

Example:

```yaml
requests:
  cpu: 100m
limits:
  cpu: 200m
```

If HPA target is:

```yaml
averageUtilization: 50
```

Then target usage is:

- 50% of 100m
- which is 50m

So if actual average CPU usage goes above 50m per pod, HPA may scale out.

---

## Important reminder

- HPA compares usage against **requests**
- HPA does **not** use limits for utilization percentage calculation

---

# 4. HPA Metric Types

You asked what metric types HPA supports other than just CPU and memory.

HPA supports **four main metric categories**.

---

## 4.1 Resource Metrics

These are the built-in resource metrics.

Examples:

- CPU
- Memory

Example:

```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

This means HPA checks average CPU utilization relative to requested CPU.

---

## 4.2 Pods Metrics

These are custom metrics averaged across pods.

Examples:

- requests per second per pod
- queue items per pod
- custom application-level metrics per pod

Example idea:

```yaml
type: Pods
pods:
  metric:
    name: requests_per_second
  target:
    type: AverageValue
    averageValue: "10"
```

---

## 4.3 Object Metrics

These are metrics tied to a specific Kubernetes object.

Examples:

- traffic on a Service
- request count on an Ingress
- some metric associated with one object

Example idea:

```yaml
type: Object
object:
  metric:
    name: requests_per_second
  describedObject:
    apiVersion: v1
    kind: Service
    name: my-service
  target:
    type: Value
    value: "100"
```

---

## 4.4 External Metrics

These are metrics from outside the cluster.

Examples:

- Kafka lag
- RabbitMQ queue size
- AWS SQS queue length
- cloud service metrics
- business metrics from external APIs

Example idea:

```yaml
type: External
external:
  metric:
    name: queue_length
  target:
    type: Value
    value: "30"
```

---

# 5. HPA Scaling Formula

At a high level, HPA calculates desired replicas like this:

```text
desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)
```

---

## Example

Suppose:

- current replicas = 2
- current average CPU = 80%
- target CPU = 50%

Then:

```text
desiredReplicas = ceil(2 × 80 / 50)
                = ceil(3.2)
                = 4
```

So HPA scales from 2 replicas to 4 replicas.

---

# 6. Important HPA Rule with Multiple Metrics

This is a very important behavior.

If HPA is configured with more than one metric, Kubernetes calculates desired replicas for each metric separately and chooses the **highest** value.

Example:

- CPU metric says 2 replicas
- Memory metric says 5 replicas

Final result:

- HPA chooses **5 replicas**

This is often called the **max rule**.

---

# 7. How You Practiced HPA

You practiced using:

- a Deployment
- a Service
- an HPA
- CPU target
- memory target
- readiness probe
- liveness probe
- minReplicas and maxReplicas
- behavior for scale up and scale down

That is already a strong practical HPA setup.

---

# 8. Readiness Probe and Liveness Probe

These were also part of your learning path.

## Readiness Probe

A readiness probe checks whether the container is ready to serve traffic.

If it fails:

- pod is not restarted
- pod is removed from Service endpoints
- traffic is not sent to that pod

---

## Liveness Probe

A liveness probe checks whether the container is still alive and functioning.

If it fails continuously:

- kubelet restarts the container

---

## Why these matter with autoscaling

Even if autoscaling adds more pods, probes are still needed so Kubernetes knows:

- whether a pod is healthy
- whether it should receive traffic

Autoscaling and health checks solve different problems.

---

# 9. Why KEDA Comes Into the Picture

You then moved from native HPA to KEDA.

## What is KEDA?

**KEDA = Kubernetes Event-Driven Autoscaling**

KEDA extends Kubernetes autoscaling and makes it easier to scale workloads based on:

- CPU
- Memory
- Prometheus metrics
- Kafka lag
- RabbitMQ queues
- AWS SQS
- metrics APIs
- cron schedules
- other external systems

---

## Why KEDA is useful

Native HPA is good, but some use cases are harder to implement directly.

KEDA makes these easier:

- event-driven autoscaling
- queue-based scaling
- Prometheus query-based scaling
- API-based scaling
- external system-driven scaling
- scale-to-zero

---

## Important understanding

KEDA does **not** completely replace HPA.

The practical model is:

```text
You define scaling rules in KEDA
    ↓
KEDA creates or manages HPA
    ↓
HPA performs the actual scaling
```

So:

- KEDA = higher-level autoscaling layer
- HPA = actual scaling engine inside Kubernetes

---

# 10. HPA Without KEDA

You asked what happens if ScaledObject does not exist and how scaling works without KEDA.

Without KEDA, autoscaling still works through native HPA.

Flow:

```text
You create HPA YAML directly
    ↓
Kubernetes HPA controller reads it
    ↓
Metrics are fetched
    ↓
Desired replicas are calculated
    ↓
Workload is scaled
```

---

## When HPA alone is enough

Native HPA is usually enough for:

- CPU-based scaling
- memory-based scaling
- simple autoscaling cases
- workloads that do not need scale-to-zero
- workloads that do not depend on queues or external event sources

---

## When HPA alone becomes harder

HPA alone becomes more complex when you need:

- queue-based scaling
- Prometheus query-based scaling
- external services
- API-derived metrics
- log-derived metrics
- scale-to-zero

That is where KEDA becomes very helpful.

---

# 11. CRD (Custom Resource Definition)

You asked several times what CRD means and why it is needed.

## Definition

**CRD = Custom Resource Definition**

A CRD is a Kubernetes mechanism used to add **new resource types** to the Kubernetes API.

---

## Built-in Kubernetes resource examples

Kubernetes already knows kinds like:

- Pod
- Deployment
- Service
- ConfigMap
- Secret
- HorizontalPodAutoscaler

---

## Custom resource examples

Kubernetes does **not** know custom kinds unless a CRD is installed.

Examples:

- ScaledObject
- ScaledJob
- CiliumNetworkPolicy
- Certificate
- VirtualService
- Application

---

## Simple meaning

```text
CRD = a way to teach Kubernetes a new resource type
```

---

# 12. CRD Definition vs Resource Instance

This distinction is very important.

There are always two separate things:

1. the **CRD definition**
2. the **actual custom resource instance**

Example with KEDA:

- `scaledobjects.keda.sh` → CRD definition
- `kind: ScaledObject` YAML you create → actual instance

---

## Easy analogy

You can think of it like:

- CRD = class definition
- custom resource = object created from that class

Or:

- CRD = blueprint
- custom resource = actual building

---

# 13. Why CRDs Are Needed

CRDs are needed because Kubernetes has to know about new resource types before users and controllers can use them.

CRDs are useful to:

- extend the Kubernetes API
- introduce domain-specific resources
- allow tools to integrate natively with Kubernetes
- let controllers watch and act on those custom resources

---

## Why not just use Deployments and Services for everything?

Because some tools need their own concepts.

Examples:

- KEDA needs a custom resource to describe event-driven scaling
- Cilium needs custom resources for advanced network policy
- cert-manager needs custom resources for certificates and issuers
- Istio needs custom resources for traffic routing

These concepts do not fit cleanly into default resources like Pod or Service.

---

# 14. What Happens Without CRD

If the CRD is not installed, Kubernetes does not recognize the custom resource kind.

Example:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-scale
```

If KEDA CRDs are not installed, applying this will fail because Kubernetes does not know what `ScaledObject` is.

Conceptually:

```text
No CRD installed
    ↓
Kubernetes does not recognize the kind
    ↓
Resource creation fails
```

So without a CRD:

- the custom kind is unknown
- Kubernetes cannot validate it
- the API server rejects it
- controllers cannot use it meaningfully

---

# 15. CRD + Controller = Useful Behavior

This was another major conceptual point.

A CRD alone only defines a new type.

A **controller/operator** is what watches that resource and performs useful actions.

So the practical idea is:

```text
CRD + Controller = useful custom behavior
```

---

## Example with KEDA

- CRD defines `ScaledObject` as a valid Kubernetes kind
- KEDA controller watches `ScaledObject`
- KEDA then creates/manages HPA based on it

Without the controller, the CRD may exist, but nothing useful happens.

---

# 16. What Is ScaledObject?

You asked multiple times what exactly a ScaledObject is.

## Definition

A **ScaledObject** is a KEDA custom resource used to define autoscaling behavior for a workload.

It tells KEDA:

- which workload to scale
- what min and max replicas to keep
- which triggers to observe
- optionally, what advanced HPA behavior to use

---

## Simple meaning

```text
ScaledObject = KEDA autoscaling configuration resource
```

---

## Another easy memory line

```text
ScaledObject = WHAT to scale + WHEN to scale
```

---

## Example

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cpu-scale
spec:
  scaleTargetRef:
    name: hpa-deployment
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
    - type: cpu
      metadata:
        value: "50"
```

---

## Important fields

### `scaleTargetRef`

Defines the workload to scale.

### `minReplicaCount`

Minimum replicas KEDA should maintain.

### `maxReplicaCount`

Maximum replicas allowed.

### `triggers`

Defines the scaling conditions.

---

# 17. Triggers

You asked whether triggers are similar to HPA metrics.

## Definition

A **trigger** in KEDA is the scaling condition you write in the YAML.

It tells KEDA:

- what source to watch
- what threshold or condition matters

---

## Examples of trigger types

- cpu
- memory
- prometheus
- kafka
- rabbitmq
- metrics-api
- cron

---

## Example

```yaml
triggers:
  - type: cpu
    metadata:
      value: "50"
```

Meaning:

- use CPU as the scaling source
- use threshold value 50

---

## Relationship with HPA metrics

Conceptually, KEDA triggers are similar to HPA metrics.

You can remember it like this:

```text
KEDA triggers ≈ HPA metrics
```

Not exactly the same schema, but similar in purpose.

---

# 18. Scalers

You also asked whether triggers and scalers are the same.

They are related, but they are not the same.

## Definition

A **scaler** is internal KEDA logic that knows how to fetch and evaluate metrics from a specific source.

Examples:

- CPU scaler
- Memory scaler
- Prometheus scaler
- Kafka scaler
- RabbitMQ scaler

---

## Important point

You do **not** usually define scalers directly.

You define **triggers**.

KEDA reads the trigger type and internally picks the correct scaler.

---

# 19. Trigger vs Scaler

This was one of the biggest confusion points, so here is the clearest summary.

## Trigger

- written by you
- present in YAML
- tells KEDA what source or condition to monitor

## Scaler

- built inside KEDA
- usually not written by you directly
- fetches and evaluates the actual metric from the source

---

## Best one-line summary

```text
Trigger = WHAT to monitor
Scaler = HOW to monitor it
```

---

## Another strong memory line

```text
Trigger selects the scaler
Scaler collects the metric
```

---

## Comparison Table

| Item | Trigger | Scaler |
|------|---------|--------|
| Defined by | User | KEDA |
| Written in YAML | Yes | Usually no |
| Purpose | Declares source/condition | Fetches and evaluates metric |
| Example | `type: cpu` | CPU scaler logic |

---

# 20. Does Kubernetes Use the Scaler?

You asked whether Kubernetes directly uses the scaler depending on the trigger.

The accurate answer is:

**KEDA uses the scaler, not Kubernetes directly.**

Flow:

```text
ScaledObject
    ↓
KEDA reads trigger type
    ↓
KEDA selects matching scaler
    ↓
Scaler fetches metric or activity
    ↓
KEDA exposes/manages metric behavior for HPA
    ↓
HPA scales the workload
```

So the correct refined statement is:

```text
Based on the trigger in ScaledObject, KEDA uses the corresponding scaler, and HPA then performs the actual scaling.
```

---

# 21. Are Scalers CRDs?

You asked whether all scalers are installed as CRDs.

## Answer

No. **Scalers are not CRDs.**

---

## What KEDA installs as CRDs

Typical KEDA CRDs include:

- `scaledobjects.keda.sh`
- `scaledjobs.keda.sh`
- `triggerauthentications.keda.sh`
- `clustertriggerauthentications.keda.sh`

You also saw eventing-related CRDs such as:

- `cloudeventsources.eventing.keda.sh`
- `clustercloudeventsources.eventing.keda.sh`

---

## What scalers are

Scalers are internal KEDA implementations or modules.

So:

- ScaledObject = CRD-backed resource
- scaler = internal KEDA logic

---

# 22. Is ScaledObject Installed Automatically?

You asked whether installing KEDA automatically installs the ScaledObject CRD.

## Answer

Yes.

When KEDA is installed, the required CRDs are normally installed as part of that installation.

So the flow is:

```text
Install KEDA
    ↓
ScaledObject CRD becomes available
    ↓
You can create ScaledObject resources
```

You usually do **not** install the ScaledObject CRD separately.

---

# 23. HPA vs KEDA — Big Picture

This is the cleanest comparison.

## Native HPA model

```text
You write HPA YAML directly
    ↓
Kubernetes HPA controller reads it
    ↓
Metrics are checked
    ↓
Scaling happens
```

---

## KEDA model

```text
You write ScaledObject YAML
    ↓
KEDA reads triggers
    ↓
KEDA selects scaler
    ↓
KEDA creates/manages HPA
    ↓
HPA performs scaling
```

---

## Best practical understanding

- HPA is the native Kubernetes scaling engine
- KEDA is a higher-level event-driven scaling layer built on top of HPA

---

# 24. KEDA Behavior / Policies

You also asked whether advanced behavior can be written in ScaledObject.

Yes. KEDA allows advanced scaling behavior settings that influence how HPA behaves.

---

## Important split

### Triggers

Triggers decide **how many replicas are needed**.

### Behavior

Behavior controls **how fast scaling happens**.

---

## Examples of behavior-related settings

- stabilization windows
- scale-up policies
- scale-down policies
- percent-based scaling
- pod-count-based scaling
- policy selection like Min/Max

---

## Easy memory line

```text
Triggers decide scaling size
Behavior decides scaling speed
```

---

# 25. Scale to Zero

One of KEDA’s most important practical advantages is **scale-to-zero** support.

This means:

- when there is no work
- and no event/activity to process
- KEDA can reduce replicas to 0

This is very useful for:

- queue consumers
- background workers
- event-driven services

Native HPA alone is not commonly used for this kind of event-driven zero-scaling pattern in the same convenient way that KEDA supports.

---

# 26. Java Heap Memory and Logs Discussion

You asked which trigger/scaler would be used for Java heap memory and Java-related logs.

There is no built-in “java heap” trigger in KEDA.

The correct trigger depends on **where the metric comes from**.

---

## Java heap memory

A common approach is:

- expose JVM metrics through Prometheus
- use a Prometheus trigger in KEDA
- KEDA internally uses the Prometheus scaler

Possible metrics:

- heap used percentage
- GC pressure
- thread count
- memory pool usage

---

## Java-related logs

KEDA usually does not scale directly from raw logs.

The common pattern is:

- logs are converted into metrics
- those metrics are exposed to Prometheus or an API
- KEDA scales using those derived metrics

Possible routes:

- logs → Prometheus metric → `prometheus` trigger
- logs → API value → `metrics-api` trigger

---

## Engineering note

Using Java heap or logs as scaling input is possible, but many systems prefer stronger primary signals such as:

- queue length
- request rate
- backlog
- latency
- event volume

Heap or log metrics are often secondary or supporting indicators.

---

# 27. CiliumNetworkPolicy as a CRD Example

You asked whether this is also a CRD:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
```

Yes, it is a CRD-backed custom resource.

Why?

Because the native Kubernetes network policy is:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
```

But `CiliumNetworkPolicy` is not a default built-in Kubernetes kind. It becomes valid only after Cilium installs its CRD.

So this is another real-world CRD example.

---

# 28. Other Common CRD Examples

| Tool | Kind | Purpose |
|------|------|---------|
| KEDA | `ScaledObject` | event-driven autoscaling |
| KEDA | `ScaledJob` | event-driven job scaling |
| Cilium | `CiliumNetworkPolicy` | advanced network policy |
| cert-manager | `Certificate` | certificate management |
| cert-manager | `Issuer` / `ClusterIssuer` | certificate issuance |
| Istio | `VirtualService` | traffic routing |
| Istio | `DestinationRule` | traffic behavior |
| ArgoCD | `Application` | GitOps deployment object |
| Prometheus Operator | `ServiceMonitor` | scrape configuration |

---

# 29. Useful Commands

These are the practical commands you used or needed for understanding KEDA and CRDs.

## List all CRDs

```bash
kubectl get crd
```

---

## List KEDA CRDs

```bash
kubectl get crd | grep keda
```

Example output:

```text
cloudeventsources.eventing.keda.sh
clustercloudeventsources.eventing.keda.sh
clustertriggerauthentications.keda.sh
scaledjobs.keda.sh
scaledobjects.keda.sh
triggerauthentications.keda.sh
```

---

## View CRD definition YAML

```bash
kubectl get crd scaledobjects.keda.sh -o yaml
```

This shows the **schema/definition** of the CRD.

---

## View all ScaledObject instances

```bash
kubectl get scaledobjects -A
```

---

## View one ScaledObject in YAML

```bash
kubectl get scaledobject <name> -n <namespace> -o yaml
```

This shows the actual instance/resource.

---

## Describe a ScaledObject

```bash
kubectl describe scaledobject <name> -n <namespace>
```

Useful for troubleshooting.

---

## View HPAs

```bash
kubectl get hpa -A
```

This helps verify that KEDA has created or is managing HPA objects.

---

# 30. Practical Learning Path

A good way to learn these topics step by step is:

## Step 1

Understand native HPA first:

- Deployment
- Service
- resource requests
- CPU target
- memory target
- HPA behavior

---

## Step 2

Install KEDA and verify CRDs:

```bash
kubectl get crd | grep keda
```

---

## Step 3

Create a simple ScaledObject with a CPU trigger.

This helps connect:

- HPA metrics
- KEDA triggers
- ScaledObject meaning

---

## Step 4

Try external-style triggers:

- Prometheus
- Kafka
- RabbitMQ
- metrics-api

---

## Step 5

Observe generated HPA:

```bash
kubectl get hpa -A
```

This is one of the best ways to understand that KEDA is managing HPA under the hood.

---

# 31. Key Clarifications From the Conversation

These are the important corrected understandings.

## Clarification 1

❌ Different ScaledObjects are automatically created depending on trigger  
✅ You create a ScaledObject resource, and inside it you define one or more triggers.

---

## Clarification 2

❌ Trigger and scaler are the same  
✅ They are related, but different.

- trigger = configuration written by user
- scaler = internal KEDA implementation

---

## Clarification 3

❌ Kubernetes directly uses the scaler  
✅ KEDA uses the scaler; HPA uses the resulting metrics/behavior to scale.

---

## Clarification 4

❌ ScaledObject exists in Kubernetes by default  
✅ No. It becomes valid only after the KEDA CRD is installed.

---

## Clarification 5

❌ ScaledObject CRD must be installed manually every time  
✅ Normally no. Installing KEDA installs its CRDs.

---

## Clarification 6

❌ HPA metadata and KEDA trigger metadata are the same kind of flexible structure  
✅ No. HPA has a strict schema. KEDA allows flexible trigger metadata because KEDA interprets it.

---

## Clarification 7

❌ HPA uses limits for utilization calculations  
✅ No. HPA uses requests for utilization-based resource scaling.

---

# 32. Strong Memory Lines

These are the best one-line takeaways.

## For CRD

```text
CRD adds a new resource type to Kubernetes.
```

---

## For ScaledObject

```text
ScaledObject is KEDA’s custom autoscaling resource.
```

---

## For trigger vs scaler

```text
Trigger = what to watch
Scaler = how to fetch/evaluate it
```

---

## For HPA calculation

```text
HPA compares current metric value with desired target and calculates replicas.
```

---

## For HPA requests

```text
HPA resource utilization is based on requests, not limits.
```

---

## For KEDA flow

```text
ScaledObject → Trigger → Scaler → HPA → Pod scaling
```

---

## For CRD + controller

```text
CRD defines the resource, controller makes it useful.
```

---

## For KEDA and HPA relationship

```text
KEDA extends and manages HPA; HPA performs the actual scaling.
```

---

# 33. Final End-to-End Summary

```text
Kubernetes natively supports autoscaling through HPA.
HPA can scale workloads using resource, pods, object, and external metrics.

For CPU and memory utilization scaling, HPA uses resource requests, not limits.
Requests are also important for scheduling, while limits protect the node and workload isolation.

For simple CPU/memory-based scaling, native HPA is often enough.

KEDA is introduced when scaling needs become more event-driven or external:
queues, Prometheus queries, APIs, external systems, or scale-to-zero use cases.

KEDA introduces ScaledObject as a custom resource.
ScaledObject exists because KEDA installs a CRD.
A CRD is needed because ScaledObject is not a built-in Kubernetes kind.

Triggers are the scaling conditions written by the user.
Scalers are the internal KEDA components that know how to fetch and evaluate metrics from real systems.

KEDA reads the trigger, selects the right scaler, and creates/manages HPA.
HPA then performs the actual pod scaling.

Without the CRD, Kubernetes would not understand ScaledObject.
Without the controller, the CRD would exist but nothing useful would happen.
```

---

# 34. Quick Revision Table

| Concept | Meaning |
|---------|---------|
| HPA | native Kubernetes autoscaling resource |
| KEDA | event-driven autoscaling layer on top of HPA |
| CRD | custom resource definition that adds new kinds |
| ScaledObject | KEDA custom resource for autoscaling |
| Trigger | scaling condition written in YAML |
| Scaler | internal KEDA logic that fetches/evaluates metrics |
| Requests | minimum resources used for scheduling and HPA utilization base |
| Limits | maximum resources enforced on container runtime |
| HPA metrics | native autoscaling metric definitions |
| KEDA triggers | simplified or extended scaling inputs |
| Behavior | controls speed and policy of scaling |

---

