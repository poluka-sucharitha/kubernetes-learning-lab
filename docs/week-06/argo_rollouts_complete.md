# Argo Rollouts — Complete Theory & Architecture Notes
### For 3 YOE DevOps Engineer — Resume & Interview Ready

---

## 1. What is Argo Rollouts?

Argo Rollouts is a **Kubernetes controller** that replaces the standard
`Deployment` object with a smarter one called `Rollout`.

It gives you **progressive delivery** — instead of replacing all pods at
once, you control exactly how traffic shifts to the new version, watch
metrics, and automatically roll back if something goes wrong.

```
Standard Kubernetes Deployment:
  "replace old pods with new pods — done"
  No traffic control. No metrics check. No auto-rollback.

Argo Rollouts:
  "send 10% traffic to new version first
   wait and watch error rates
   if good  → send 50% → then 100%
   if bad   → automatically rollback"
```

---

## 2. The Problem It Solves

### Without Argo Rollouts (standard rolling update):

```
Old version running: 10 pods
        ↓
Kubernetes starts replacing pods one by one
        ↓
5 old + 5 new running simultaneously
        ↓
New version has a bug — 500 errors for 50% of users
        ↓
You notice after 5 minutes
        ↓
Manual rollback needed — users already impacted
```

### With Argo Rollouts (canary):

```
Old version running: 10 pods
        ↓
Send only 5% traffic to new version
        ↓
Error rate spikes above threshold
        ↓
Automatic rollback in seconds
        ↓
Only 5% of users saw any issue — rest unaffected
```

---

## 3. Argo Rollouts vs Standard Kubernetes Deployment

```
Standard Deployment              Argo Rollouts (Rollout)
────────────────────────────────────────────────────────
kind: Deployment                 kind: Rollout
Basic rolling update             Canary + Blue-Green
No traffic control               Fine-grained traffic control
No metric analysis               Automated metric analysis
Manual rollback                  Automatic rollback
No pause/resume                  Pause at any canary step
All-or-nothing                   Gradual / controlled
```

The `Rollout` object is almost identical to a `Deployment`:
- Same `spec.template`
- Same `replicas`
- Same `selector`

You just change `kind: Deployment` → `kind: Rollout` and add a
`strategy` block.

---

## 4. The Two Main Strategies

### Strategy 1 — Canary Deployment

Send a small percentage of traffic to the new version first.
Gradually increase if metrics are healthy.
Roll back automatically if they are not.

```
Step 1:  5% → new version  |  95% → old version
         wait 5 min, check error rate ✅
         ↓
Step 2: 20% → new version  |  80% → old version
         wait 5 min, check error rate ✅
         ↓
Step 3: 50% → new version  |  50% → old version
         wait 5 min, check error rate ✅
         ↓
Step 4: 100% → new version |  old version removed ✅

If ANY step fails → automatic rollback to 100% old version
```

**Production YAML:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout                        # replaces kind: Deployment
metadata:
  name: payments-api
  namespace: payments-prod
spec:
  replicas: 10
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      containers:
        - name: api
          image: payments-api:v2.0
          ports:
            - containerPort: 8080

  strategy:
    canary:
      steps:
        - setWeight: 5               # send 5% to new version
        - pause: {duration: 5m}      # wait 5 minutes
        - setWeight: 20              # send 20%
        - pause: {duration: 5m}
        - setWeight: 50              # send 50%
        - pause: {duration: 5m}
        - setWeight: 100             # full rollout

      # automatic rollback rules
      analysis:
        templates:
          - templateName: error-rate-check
        args:
          - name: service-name
            value: payments-api
```

---

### Strategy 2 — Blue-Green Deployment

Run TWO complete environments simultaneously.
Switch all traffic at once when ready.
Old version stays running as instant rollback option.

```
BEFORE deployment:
  Blue  (v1 — current) ← 100% live traffic
  Green (empty)

DURING deployment:
  Blue  (v1) ← 100% live traffic (users unaffected)
  Green (v2) ← spun up, tested internally, no user traffic

AFTER testing Green is healthy:
  Blue  (v1) ← 0% traffic  (kept running for rollback)
  Green (v2) ← 100% live traffic

ROLLBACK if needed:
  Blue  (v1) ← 100% traffic  (instant switch back)
  Green (v2) ← terminated
```

**Production YAML:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payments-api
spec:
  replicas: 5
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      containers:
        - name: api
          image: payments-api:v2.0

  strategy:
    blueGreen:
      # service receiving live traffic
      activeService: payments-api-active

      # service for new version (preview/testing)
      previewService: payments-api-preview

      # false = wait for manual approval before switching
      autoPromotionEnabled: false

      # keep old version running 30 min after switch
      # gives instant rollback window
      scaleDownDelaySeconds: 1800
```

---

## 5. Canary vs Blue-Green — When to Use Each

```
Canary                              Blue-Green
──────────────────────────────────────────────────────────
Gradual traffic shift               Instant traffic switch
Good for: APIs, microservices       Good for: databases, stateful apps
Lower resource cost                 Higher cost (2x pods running)
Real users test it gradually        Test before any user sees it
Rollback = gradual revert           Rollback = instant switch
Best for: high traffic services     Best for: critical zero-downtime
```

---

## 6. ArgoCD vs Argo Rollouts — The Difference

This is the most important distinction to understand.

```
ArgoCD          =  HOW code gets from Git to cluster
                   (the delivery mechanism / GitOps engine)

Argo Rollouts   =  HOW traffic shifts between versions
                   (the release strategy controller)
```

They are **separate tools** in the same Argo project family.

### The Argo Project — 4 Tools:

```
ArgoCD          →  GitOps CD (continuous delivery)
Argo Rollouts   →  Progressive delivery (Canary, Blue-Green)
Argo Workflows  →  Pipeline / workflow engine
Argo Events     →  Event-driven automation
```

### How They Work Together in Production:

```
Git push (new image tag)
        ↓
ArgoCD detects change → syncs Rollout manifest to cluster
        ↓
Argo Rollouts controller takes over
        ↓
Starts canary / blue-green process
        ↓
Traffic shifts gradually (canary) or switches (blue-green)
        ↓
Metrics checked automatically via Prometheus/Datadog
        ↓
Full rollout if healthy OR automatic rollback if not
```

```
ArgoCD        =  gets the manifest to the cluster
Argo Rollouts =  controls how traffic moves to new version
```

---

## 7. Argo Rollouts + Kong / Istio / Gateway

### The Question: If I already have Kong or Istio, do I need Argo Rollouts?

**Answer: They serve different purposes — they complement each other.**

```
Kong / Istio / Gateway API
  → does the ACTUAL traffic routing
  → routes by path, header, method, weight
  → CAN split traffic manually
  → does NOT watch metrics
  → does NOT auto-rollback

Argo Rollouts
  → AUTOMATES the weight changes over time
  → watches Prometheus / Datadog metrics
  → promotes or rolls back automatically
  → tells Kong/Istio what weights to set
  → the BRAIN on top of your gateway
```

### Analogy:

```
Kong / Istio    =  the road network
                   decides which road traffic takes

Argo Rollouts   =  the traffic controller
                   changes road capacity from 10% → 20% → 50%
                   closes the road if accidents happen
```

---

## 8. Dynamic Routing vs Progressive Delivery

**This is a common confusion — they are different things.**

```
Dynamic Routing                    Progressive Delivery
────────────────────────────────────────────────────────
Route by path, header, method      Change traffic % over time
/payments → payments service       10% → 20% → 50% → 100%
X-Beta-User → v2 service           Based on deployment steps
Kong / Istio handles this          Argo Rollouts handles this
No Argo Rollouts needed            Kong/Istio does the routing
```

### Dynamic Routing — Kong/Istio alone is enough:

```yaml
# path-based routing — no Argo Rollouts needed
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
    - matches:
        - path:
            value: /payments
      backendRefs:
        - name: payments-service
          port: 8080
    - matches:
        - path:
            value: /orders
      backendRefs:
        - name: orders-service
          port: 8080
```

```yaml
# header-based routing — no Argo Rollouts needed
rules:
  - matches:
      - headers:
          - name: X-Beta-User
            value: "true"
    backendRefs:
      - name: payments-api-v2
        port: 8080
  - backendRefs:
      - name: payments-api-v1
        port: 8080
```

### Automated canary — Argo Rollouts adds value here:

```yaml
# Argo Rollouts automatically changes weights AND
# watches metrics — Kong alone cannot do this
steps:
  - setWeight: 10
  - pause: {duration: 5m}    # Prometheus checked here
  - setWeight: 50
  - pause: {duration: 5m}    # Prometheus checked here
  - setWeight: 100
```

---

## 9. Production Architecture — All Together

```
Developer pushes code
        ↓
CI builds image → pushes to ECR
        ↓
CI updates image tag in GitOps repo
        ↓
ArgoCD detects Git change → syncs Rollout YAML to cluster
        ↓
Argo Rollouts controller starts canary
        ↓
Argo Rollouts tells Kong:
  "set HTTPRoute weight: 10% v2 / 90% v1"
        ↓
Kong routes traffic accordingly
        ↓
Argo Rollouts queries Prometheus:
  "error rate for v2?"
  ↓ OK → tells Kong "set 30% v2 / 70% v1"
  ↓ OK → tells Kong "set 100% v2 / 0% v1"
  ↓ SPIKE → tells Kong "set 0% v2 / 100% v1"
             rollback complete — zero manual intervention
```

---

## 10. Gateway Support in Argo Rollouts

Argo Rollouts natively integrates with all major gateways:

```
Istio              →  VirtualService + DestinationRule
Kong Gateway       →  HTTPRoute (via Gateway API plugin)
AWS ALB            →  TargetGroup weights
NGINX Ingress      →  annotation-based weight
Traefik            →  TraefikService weights
Ambassador         →  Mapping weights
Linkerd            →  SMI TrafficSplit
```

---

## 11. Argo Rollouts with Istio — VirtualService + DestinationRule

```yaml
# VirtualService — Argo Rollouts updates weights automatically
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: payments-api
spec:
  http:
    - route:
        - destination:
            host: payments-api
            subset: stable        # old version
          weight: 90
        - destination:
            host: payments-api
            subset: canary        # new version
          weight: 10
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: payments-api
spec:
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

Argo Rollouts automatically updates these weights at each step.
You do not manually edit the VirtualService.

---

## 12. Manual vs Automated — The Core Difference

```
WITHOUT Argo Rollouts (manual):
  You edit weights in HTTPRoute/VirtualService
  Push to Git → ArgoCD syncs
  You watch Grafana yourself
  You decide when to move to next step
  You manually rollback if something breaks
  You must be awake and watching

WITH Argo Rollouts (automated):
  Argo Rollouts updates weights automatically
  Prometheus metrics watched automatically
  Rollback happens automatically
  No human needed during deployment
  You can sleep while deployment runs
```

---

## 13. Decision Framework

```
Do you need automated metric analysis + auto-rollback?
        YES → use Argo Rollouts + your gateway
        NO  → use gateway traffic splitting manually

Is this a critical production service?
        YES → Argo Rollouts (auto-rollback saves you)
        NO  → manual weights in Git is fine

Do you have Prometheus / Datadog set up?
        YES → Argo Rollouts uses them for analysis
        NO  → Argo Rollouts still works, just no auto-analysis

Is your team small / staging environment?
        YES → manual gateway weights is fine
        NO  → Argo Rollouts is worth the setup
```

---

## 14. Argo Rollouts UI

Separate dashboard from ArgoCD UI where you can:
- See which canary step is currently active
- See traffic percentages in real time
- See metric analysis results (pass/fail)
- Manually promote (move to next step)
- Manually abort (instant rollback)

---

## 15. Summary Table — All Tools

```
Tool                  Type                  What it does
──────────────────────────────────────────────────────────────
ArgoCD                CD / GitOps engine    Git → cluster delivery
Argo Rollouts         Deployment strategy   Canary + Blue-Green automation
Kong / Gateway API    Traffic routing       Path, header, weight routing
Istio                 Service mesh          mTLS + fine-grained traffic
Standard Deployment   Basic K8s             Rolling update, no control
```

---

## 16. Resume Bullet Points

- Implemented progressive delivery using Argo Rollouts with canary
  deployments, starting at 5% traffic with automated Prometheus metric
  analysis and automatic rollback on error rate threshold breach
- Configured Blue-Green deployments for stateful services using Argo
  Rollouts with a 30-minute rollback window and manual promotion gates
- Integrated Argo Rollouts with Kong Gateway API for automated HTTPRoute
  weight management during canary deployments across production
  microservices
- Combined ArgoCD for GitOps delivery with Argo Rollouts for progressive
  delivery, separating concerns between manifest management and traffic
  strategy

---

## 17. Interview One-Liners

**What is Argo Rollouts?**
> Argo Rollouts is a Kubernetes controller that replaces standard
> Deployments with a Rollout object supporting Canary and Blue-Green
> strategies, automated metric analysis via Prometheus or Datadog, and
> automatic rollback when error thresholds are breached.

**Difference between ArgoCD and Argo Rollouts?**
> ArgoCD is a GitOps CD tool that delivers manifests from Git to the
> cluster. Argo Rollouts controls how traffic progressively shifts to a
> new version after delivery, with automated promotion and rollback based
> on metrics. They are complementary — ArgoCD delivers, Argo Rollouts
> controls the release.

**Do you need Argo Rollouts if you have Kong or Istio?**
> Kong and Istio can split traffic manually by editing weights in
> HTTPRoute or VirtualService. But that requires human intervention at
> each step and manual monitoring. Argo Rollouts sits on top of
> Kong/Istio and automates the weight changes at each canary step while
> querying Prometheus metrics to decide whether to promote or rollback —
> removing the human from the critical path of a production deployment.

**When to use Canary vs Blue-Green?**
> Canary is better for high-traffic APIs and microservices where you want
> real traffic to gradually validate the new version with minimal blast
> radius. Blue-Green is better for stateful services or database-backed
> apps where you need to test the full environment before any user sees
> it and need instant rollback capability.

---
*Argo Rollouts Notes — 3 YOE DevOps Engineer Level*
