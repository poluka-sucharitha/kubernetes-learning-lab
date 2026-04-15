# Kyverno — Complete Study Notes
> DevOps Engineer Reference Guide | Theory + Q&A  
> For interview prep, resume documentation, and GitHub reference

---

## Table of Contents

1. [What Problem Does Kyverno Solve?](#1-what-problem-does-kyverno-solve)
2. [What Kyverno Actually Is](#2-what-kyverno-actually-is)
3. [The Three Powers of Kyverno](#3-the-three-powers-of-kyverno)
4. [How Kyverno Works Internally](#4-how-kyverno-works-internally)
5. [Anatomy of a Kyverno Policy](#5-anatomy-of-a-kyverno-policy)
6. [The match / exclude Engine](#6-the-match--exclude-engine)
7. [VALIDATE — Deep Dive](#7-validate--deep-dive)
8. [MUTATE — Deep Dive](#8-mutate--deep-dive)
9. [GENERATE — Deep Dive](#9-generate--deep-dive)
10. [Kyverno + ArgoCD in Production](#10-kyverno--argocd-in-production)
11. [Policy Exceptions — The Enterprise Reality](#11-policy-exceptions--the-enterprise-reality)
12. [Kyverno in Enterprise — Full Picture](#12-kyverno-in-enterprise--full-picture)
13. [Most Used Kyverno Policies (Production List)](#13-most-used-kyverno-policies-production-list)
14. [Q&A — Cross Questions Answered](#14-qa--cross-questions-answered)
15. [Quick Reference — Mental Models](#15-quick-reference--mental-models)

---

## 1. What Problem Does Kyverno Solve?

Before Kyverno, ask yourself — **what stops a developer from deploying this to your cluster?**

```yaml
containers:
  - name: app
    image: myapp:latest        # no digest, unpinned
    securityContext:
      runAsRoot: true          # running as root
    resources: {}              # no CPU/memory limits
```

**Nothing.** Kubernetes will happily schedule it. It doesn't care.

At enterprise scale — 50 teams, 200 microservices, 10 clusters — without guardrails:

| Problem | Real-World Consequence |
|---|---|
| Images running as root | Security breach blast radius explodes |
| No resource limits | One bad pod starves the entire node |
| Images from unknown registries | Supply chain attack surface |
| Missing labels | No cost attribution, no alerting routing |
| No network policies | Lateral movement after compromise |

**Kyverno fills this gap.** It is a **Policy Engine for Kubernetes** — it intercepts every resource before it lands in the cluster and applies your rules.

---

## 2. What Kyverno Actually Is

> **One-line definition:** Kyverno is a Kubernetes-native policy engine that validates, mutates, and generates resources using policies written as plain Kubernetes YAML — no new language to learn.

The name comes from the Greek word **κυβερνώ** — *to govern*. Same root as Kubernetes (*κυβερνήτης* — helmsman). Literally: **governance for your cluster**.

### Where Kyverno sits in your stack

```
Developer pushes code
        ↓
CI Pipeline (Jenkins / GitHub Actions)
        ↓
Image built → pushed to registry (JFrog / ECR)
        ↓
ArgoCD detects Git change → applies manifests
        ↓
  ┌─────────────────────────────────┐
  │   Kubernetes API Server         │
  │                                 │
  │   → Kyverno intercepts HERE ←  │   ← THIS is where Kyverno lives
  │                                 │
  └─────────────────────────────────┘
        ↓
Resource lands in cluster (or gets rejected)
```

Kyverno sits between **ArgoCD applying manifests** and **Kubernetes actually scheduling them**. It is the last gate.

---

## 3. The Three Powers of Kyverno

### Power 1: VALIDATE
> *"This resource must look a certain way — or it gets rejected."*

```
Pod comes in with runAsRoot: true
        ↓
Kyverno checks your Validate policy
        ↓
DENIED — "Root containers are not allowed"
        ↓
ArgoCD sync fails, developer gets error
```

This is your **enforcement** mechanism — hard stops.

---

### Power 2: MUTATE
> *"This resource is missing something — let me add it automatically."*

```
Pod comes in with no resource limits defined
        ↓
Kyverno checks your Mutate policy
        ↓
Kyverno automatically INJECTS default limits
        ↓
Pod lands in cluster with limits already set
```

This is your **auto-remediation** mechanism — silent fixes.

---

### Power 3: GENERATE
> *"When this resource is created, automatically create these other resources."*

```
New Namespace "team-payments" is created
        ↓
Kyverno detects new Namespace
        ↓
Kyverno automatically creates:
  - NetworkPolicy (deny all ingress by default)
  - ResourceQuota (CPU/memory caps for the team)
  - LimitRange (default container limits)
```

This is your **scaffolding** mechanism — zero-touch provisioning.

---

## 4. How Kyverno Works Internally

### The Admission Webhook — the core mechanism

Kubernetes has a built-in extension point called **Admission Controllers**. When any resource is created/updated/deleted, Kubernetes calls external webhooks before persisting the change.

Kyverno registers itself as **two webhooks**:

| Webhook Type | When Called | Can it Reject? | Kyverno Use |
|---|---|---|---|
| **MutatingAdmissionWebhook** | Before validation | No (only modifies) | MUTATE policies |
| **ValidatingAdmissionWebhook** | After mutation | **Yes** | VALIDATE policies |

### Full admission flow

```
kubectl apply / ArgoCD apply
        ↓
API Server receives request
        ↓
Authentication & Authorization (RBAC)
        ↓
┌──────────────────────────────────┐
│  MutatingAdmissionWebhook        │  ← Kyverno MUTATE runs here
│  (Kyverno adds missing fields)   │
└──────────────────────────────────┘
        ↓
┌──────────────────────────────────┐
│  ValidatingAdmissionWebhook      │  ← Kyverno VALIDATE runs here
│  (Kyverno checks rules, DENY?)   │
└──────────────────────────────────┘
        ↓
Object Schema Validation
        ↓
Persisted to etcd ✅
```

### Key interview insight

> *"Kyverno doesn't run as a sidecar or agent on nodes. It runs as a central controller and registers admission webhooks with the API server. Every resource CREATE/UPDATE/DELETE goes through it — no agent required."*

---

## 5. Anatomy of a Kyverno Policy

### Two policy scopes

| Resource | Scope | Use Case |
|---|---|---|
| `ClusterPolicy` | Cluster-wide | Applies to all namespaces |
| `Policy` | Namespace-scoped | Applies to one namespace only |

> In production, **95% of your policies will be `ClusterPolicy`**.

### The skeleton every policy follows

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: <descriptive-name>
spec:
  validationFailureAction: Enforce   # or Audit
  background: true                   # scan existing resources too
  rules:
    - name: <rule-name>
      match:                         # WHICH resources does this apply to?
        any:
        - resources:
            kinds:
              - Pod
      exclude:                       # EXCEPTIONS to the match
        ...
      validate:                      # WHAT to check (or mutate/generate)
        message: "Human-readable error"
        pattern:
          spec:
            containers:
              - (name): "*"
                resources:
                  limits:
                    memory: "?*"    # must exist and be non-empty
```

### The two most important fields

**`validationFailureAction`** — your enforcement dial:

| Value | Behavior | When to Use |
|---|---|---|
| `Audit` | Logs violations, **never blocks** | Rollout phase — see what would break |
| `Enforce` | **Blocks** non-compliant resources | Production — hard enforcement |

> Always start with `Audit`, monitor for 1–2 weeks, fix violations, then switch to `Enforce`. Never flip Enforce on a new policy in prod directly.

**`background: true`** — when true, Kyverno scans **already-existing** resources in the cluster, not just new incoming ones. Critical for compliance reporting.

---

## 6. The match / exclude Engine

### match — which resources the rule applies to

```yaml
match:
  any:                          # match if ANY of these are true
  - resources:
      kinds:
        - Pod
        - Deployment
      namespaces:
        - production
        - staging
      selector:
        matchLabels:
          app.kubernetes.io/managed-by: argocd
```

### exclude — carve out exceptions

```yaml
exclude:
  any:
  - resources:
      namespaces:
        - kube-system          # never touch system namespaces
        - argocd               # never touch ArgoCD's own pods
  - subjects:
    - kind: Group
      name: system:masters     # exclude cluster-admin users
```

> **Real production pattern:** Always exclude `kube-system`, `kube-public`, `argocd` namespaces from policies. You don't want Kyverno blocking Kubernetes system pods or ArgoCD's own components.

---

## 7. VALIDATE — Deep Dive

### Pattern matching — Kyverno's DSL

| Pattern | Meaning |
|---|---|
| `"?*"` | Must exist and be non-empty |
| `"*"` | Any value (wildcard) |
| `"!root"` | Must NOT equal "root" |
| `">0"` | Must be greater than 0 |
| `"/^(Always\|Never)$/"` | Regex match |

### Example — Disallow latest image tag

```yaml
validate:
  message: "Image tag 'latest' is not allowed. Use a specific version."
  pattern:
    spec:
      containers:
      - (name): "*"
        image: "!*:latest"   # image must NOT end in :latest
```

### Deny rules — for complex conditions

```yaml
validate:
  message: "Privileged containers are not allowed"
  deny:
    conditions:
      any:
      - key: "{{ request.object.spec.containers[].securityContext.privileged }}"
        operator: AnyIn
        value:
        - true
```

---

## 8. MUTATE — Deep Dive

### Style 1: patchStrategicMerge — YAML overlay

```yaml
mutate:
  patchStrategicMerge:
    spec:
      containers:
      - (name): "*"              # match all containers
        resources:
          limits:
            +(memory): "512Mi"   # + means: only add if NOT already present
            +(cpu): "500m"
```

> The `+` prefix means **"only set this if it doesn't already exist."** Without `+`, you'd overwrite values developers intentionally set.

### Style 2: patchesJson6902 — surgical JSON patch

```yaml
mutate:
  patchesJson6902: |-
    - op: add
      path: /metadata/labels/environment
      value: production
```

---

## 9. GENERATE — Deep Dive

When a resource matching your rule is created, Kyverno creates additional resources automatically.

### Classic enterprise use case — Namespace bootstrapping

```yaml
rules:
  - name: create-default-network-policy
    match:
      any:
      - resources:
          kinds:
          - Namespace
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: default-deny-ingress
      namespace: "{{request.object.metadata.name}}"  # same ns as trigger
      synchronize: true     # keep it in sync; recreate if manually deleted
      data:
        spec:
          podSelector: {}
          policyTypes:
          - Ingress
```

> **`synchronize: true`** — if someone manually deletes the generated NetworkPolicy, Kyverno will **recreate it**. GitOps-style enforcement for generated resources.

---

## 10. Kyverno + ArgoCD in Production

### The workflow

```
Git repo (source of truth)
    │
    ├── /manifests/           ← application YAMLs
    └── /policies/            ← Kyverno ClusterPolicies (also in Git!)
           │
           ▼
        ArgoCD
    ┌─────────────────────────────────────┐
    │  App-1: ArgoCD Application          │  ← deploys app manifests
    │  App-2: ArgoCD Application          │  ← deploys Kyverno policies
    └─────────────────────────────────────┘
           │
           ▼
    Kubernetes API Server
           │
           ▼ (admission webhook)
        Kyverno
    ┌─────────────────────────────────────┐
    │  Validates app manifests comply     │
    │  Mutates missing fields             │
    │  Generates namespace resources      │
    └─────────────────────────────────────┘
```

> **Key insight:** Your Kyverno policies themselves live in Git and are deployed by ArgoCD. **Policies are code.** Policy changes go through PR review, just like application code.

### The ArgoCD + Kyverno drift problem

When ArgoCD applies resources and Kyverno **mutates** them (adds fields), ArgoCD sees the mutated resource differs from Git — and flags it as **OutOfSync**.

**The fix:** Use ArgoCD's `ignoreDifferences` in your Application:

```yaml
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/template/spec/containers/0/resources  # Kyverno added this
```

This tells ArgoCD: *"I know this field will be modified by Kyverno — don't count it as drift."*

---

## 11. Policy Exceptions — The Enterprise Reality

In large orgs, there will always be **legacy workloads** that can't immediately comply. Kyverno has a `PolicyException` resource:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: legacy-payment-service-exception
  namespace: payments
spec:
  exceptions:
  - policyName: disallow-root-containers
    ruleNames:
    - check-runasnonroot
  match:
    any:
    - resources:
        kinds:
        - Pod
        namespaces:
        - payments
        names:
        - legacy-payment-*
```

> Tracked in Git, reviewed via PR, has an owner — **auditable exceptions**, not silent workarounds.

---

## 12. Kyverno in Enterprise — Full Picture

| Capability | What It Gives the Org |
|---|---|
| **Validate + Enforce** | Security baselines — no one can bypass |
| **Audit mode** | Compliance reports without breaking deployments |
| **Mutate** | Reduce developer cognitive load — safe defaults auto-injected |
| **Generate** | Namespace-as-a-service — teams get isolated, pre-configured namespaces |
| **PolicyException** | Managed escape hatches with audit trails |
| **Reports** | `PolicyReport` & `ClusterPolicyReport` CRDs — machine-readable compliance state |
| **Git-stored policies** | Policy-as-Code — full history, PR reviews, rollbacks |

### Interview-ready answer on enterprise rollout

> *"We used Kyverno in Audit mode first to baseline our violation state across 8 clusters. Once we had visibility, we prioritised — security-critical policies moved to Enforce first, operational policies second. PolicyExceptions were granted only via approved PRs with a named owner and a remediation deadline. Within 3 months, we had 94% policy compliance across all workloads."*

---

## 13. Most Used Kyverno Policies (Production List)

### Security Policies

| Policy | Type | Frequency |
|---|---|---|
| Disallow privileged containers | Validate | Very common |
| Disallow root user | Validate | Very common |
| Disallow latest image tag | Validate | Very common |
| Restrict image registries | Validate | Very common |
| Disallow host namespaces (hostPID, hostIPC, hostNetwork) | Validate | Very common |
| Disallow host path mounts | Validate | Common |
| Disallow dangerous capabilities (NET_ADMIN, SYS_ADMIN) | Validate | Common |
| Require read-only root filesystem | Validate | Common |

### Resource Management Policies

| Policy | Type | Frequency |
|---|---|---|
| Require resource limits | Validate | Very common |
| Require resource requests | Validate | Very common |
| Add default resource limits | Mutate | Very common |
| Require LimitRange in namespace | Validate | Common |
| Require ResourceQuota in namespace | Validate | Common |

### Labels & Metadata Policies

| Policy | Type | Frequency |
|---|---|---|
| Require standard labels (app.kubernetes.io/*) | Validate | Very common |
| Add default labels | Mutate | Very common |
| Require owner/team annotation | Validate | Common |
| Disallow default namespace | Validate | Common |

### Networking Policies

| Policy | Type | Frequency |
|---|---|---|
| Generate default NetworkPolicy (deny-all) on new namespace | Generate | Very common |
| Require NetworkPolicy in namespace | Validate | Common |
| Disallow NodePort services | Validate | Common |
| Restrict Ingress hostnames to approved domains | Validate | Common |

### Namespace Bootstrapping Policies

| Policy | Type | Frequency |
|---|---|---|
| Generate ResourceQuota on namespace creation | Generate | Very common |
| Generate LimitRange on namespace creation | Generate | Very common |
| Copy image pull secret to new namespace | Generate | Very common |
| Generate default ConfigMap for team config | Generate | Common |

### Pod Spec Hardening Policies

| Policy | Type | Frequency |
|---|---|---|
| Require liveness probe | Validate | Common |
| Require readiness probe | Validate | Common |
| Mutate image to use digest instead of tag | Mutate | Common |
| Require PodDisruptionBudget for production deployments | Validate | Situational |
| Disallow emptyDir volumes for sensitive data | Validate | Situational |

### Secret & Config Policies

| Policy | Type | Frequency |
|---|---|---|
| Disallow plain-text secrets in env vars | Validate | Very common |
| Require Sealed Secrets or External Secrets Operator | Validate | Common |
| Restrict secret access by namespace | Validate | Situational |

---

## 14. Q&A — Cross Questions Answered

### Q: Can we use Kyverno only with ArgoCD?

**No, not at all.** Kyverno is completely independent of ArgoCD.

Kyverno registers itself as an **Admission Webhook** with the Kubernetes API server. It intercepts **every single resource** that hits the API server, regardless of *what tool* sent it. It does not care who applied the manifest.

| Tool | Works with Kyverno? | How |
|---|---|---|
| ArgoCD | Yes | ArgoCD applies manifests → API Server → Kyverno intercepts |
| kubectl apply | Yes | Developer runs kubectl → API Server → Kyverno intercepts |
| Helm | Yes | Helm renders and applies → API Server → Kyverno intercepts |
| FluxCD | Yes | Flux syncs from Git → API Server → Kyverno intercepts |
| Jenkins / GitHub Actions | Yes | CI pipeline runs kubectl/helm → API Server → Kyverno intercepts |
| Terraform | Yes | Terraform applies k8s resources → API Server → Kyverno intercepts |

```
Anyone / Any tool
        ↓
  kubectl / helm / argocd / flux / terraform
        ↓
  Kubernetes API Server
        ↓
  Kyverno Admission Webhook  ← sits HERE, completely tool-agnostic
        ↓
  Resource lands in cluster (or gets rejected)
```

**Why people mention ArgoCD + Kyverno together:** In a GitOps enterprise setup, ArgoCD is the primary delivery mechanism — so naturally they are discussed together. But Kyverno works equally well in any environment.

**The real value:** You set the policy **once**, and it applies to **every path** into the cluster — no matter how the resource got there. One policy engine. Every door into the cluster is covered.

---

## 15. Quick Reference — Mental Models

### The three powers

```
VALIDATE → Gate keeper   — "Does this meet our standards?"
MUTATE   → Auto-fixer    — "Let me add what's missing"
GENERATE → Provisioner   — "Creating this triggers creation of that"
```

### Enforcement modes

```
Audit    → Observe mode  — see violations, don't block  (use during rollout)
Enforce  → Guard mode    — block non-compliant resources (use in production)
```

### Policy scopes

```
ClusterPolicy → org-wide rules      (95% of real-world policies)
Policy        → team/namespace-specific rules
PolicyException → managed, auditable escape hatches for legacy workloads
```

### Enterprise rollout order

```
1. Install Kyverno
2. Deploy policies in Audit mode
3. Review PolicyReport / ClusterPolicyReport (violations visible, nothing blocked)
4. Fix violations team by team
5. Grant PolicyExceptions for legacy workloads (via PR, with owner + deadline)
6. Flip validationFailureAction to Enforce
7. Monitor — any new violations are now blocked at the gate
```

### Kyverno vs OPA/Gatekeeper (common interview comparison)

| Feature | Kyverno | OPA / Gatekeeper |
|---|---|---|
| Policy language | Kubernetes YAML | Rego (separate language) |
| Learning curve | Low | High |
| Generate resources | Yes (native) | No |
| Mutate resources | Yes (native) | Limited |
| Kubernetes-native | Yes | Partial |
| Community adoption | Growing fast | Established |

> **Interview tip:** "We chose Kyverno because our team was already fluent in YAML and Kubernetes manifests. Rego has a steep learning curve, and Kyverno's Generate capability solved our namespace bootstrapping problem natively — we didn't need a separate tool."

---

*Notes compiled from hands-on learning sessions | Kyverno v1.x / v2.x*  
*Reference: [kyverno.io/docs](https://kyverno.io/docs/) | [Kyverno Policies Library](https://kyverno.io/policies/)*
