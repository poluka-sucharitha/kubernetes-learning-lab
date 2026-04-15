# ArgoCD — Complete Theory & Architecture Study Notes
### For 3 YOE DevOps Engineer — Resume & Interview Ready

---

## 1. What is ArgoCD?

ArgoCD is a **GitOps Continuous Deployment tool for Kubernetes**.

It watches a Git repo and makes sure your Kubernetes cluster always matches what is written there.

```
Git Repo (desired state)  ←→  ArgoCD  ←→  Kubernetes Cluster (live state)

Rule: What is in Git = What should run in the cluster
```

---

## 2. The Problem ArgoCD Solves

### Before ArgoCD (manual CD):
- Developer pushes code → CI builds image → someone runs `kubectl apply` manually
- Jenkins/scripts had direct cluster access — security risk
- No audit trail — who deployed what, when?
- Cluster becomes a black box — Git says v1.5, cluster runs v1.3
- Someone does `kubectl edit` in production at 2am — now Git and cluster are out of sync forever
- New cluster = re-run all scripts manually

### After ArgoCD (GitOps):
- CI only updates Git (image tag) — never touches cluster directly
- ArgoCD handles ALL cluster changes
- Every deployment = a Git commit = full audit trail
- Rollback = `git revert` → ArgoCD deploys previous version
- New cluster = point ArgoCD at same Git repo → everything rebuilds automatically
- Drift is auto-detected and auto-healed

---

## 3. GitOps Principle

**One rule: Git is the single source of truth.**

```
To deploy     →  push to Git        →  ArgoCD deploys
To rollback   →  revert Git commit  →  ArgoCD rolls back
Manual change →  ArgoCD detects     →  ArgoCD reverts (selfHeal)
New cluster   →  point at Git repo  →  cluster rebuilds itself
```

---

## 4. ArgoCD Architecture — All Components

```
┌─────────────────────────────────────────────────┐
│              ArgoCD (runs in K8s)               │
│                                                 │
│  ┌─────────────┐      ┌──────────────────────┐  │
│  │argocd-server│      │     repo-server      │  │
│  │             │      │                      │  │
│  │ UI / API    │─────►│ Clones Git repo      │  │
│  │ Auth / RBAC │      │ Renders Helm/Kustomize│  │
│  │ SSO/OIDC    │      │ Produces final YAML  │  │
│  └─────────────┘      └──────────────────────┘  │
│         │                       │               │
│         ▼                       ▼               │
│  ┌─────────────────────────────────────────┐    │
│  │        application-controller           │    │
│  │                                         │    │
│  │  Compares desired (Git) vs live (K8s)   │    │
│  │  Marks OutOfSync if different           │    │
│  │  Runs kubectl apply internally          │    │
│  │  Runs continuously (reconciliation loop)│    │
│  └─────────────────────────────────────────┘    │
│         │                                       │
│  ┌──────┴───────┐   ┌──────────────────────┐   │
│  │     redis    │   │      dex-server       │   │
│  │              │   │                       │   │
│  │ Caches       │   │ Handles SSO/OIDC      │   │
│  │ cluster state│   │ authentication        │   │
│  └──────────────┘   └──────────────────────┘   │
└─────────────────────────────────────────────────┘
         │
         ▼
  Kubernetes API → Cluster
```

### Component Jobs:

| Component | Job | Simple Description |
|---|---|---|
| `argocd-server` | UI, API, Auth, RBAC | Front door — everything you touch as a human |
| `repo-server` | Clone Git, render YAML | Git expert — fetches and builds manifests |
| `application-controller` | Compare + sync | The brain — detects drift, does deployments |
| `dex-server` | SSO/OIDC authentication | Login handler for Entra ID / Okta |
| `redis` | Cache cluster state | Memory — avoids hammering K8s API every loop |

---

## 5. The Reconciliation Loop

The `application-controller` runs this loop forever:

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  1. Fetch desired state ← read Git repo via         │
│     repo-server                                     │
│            ↓                                        │
│  2. Fetch live state ← query Kubernetes API         │
│            ↓                                        │
│  3. Compare: Git == Cluster?                        │
│            ↓                                        │
│     YES → Status: Synced → do nothing → loop again  │
│     NO  → Status: OutOfSync                         │
│            ↓                                        │
│  4. If auto-sync ON → kubectl apply internally      │
│     If selfHeal ON → revert manual changes          │
│            ↓                                        │
│  5. Loop restarts (every 3 min or via webhook)      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 6. Where ArgoCD Fits in Full CI/CD Pipeline

```
Developer pushes code
        ↓
CI (Jenkins / GitHub Actions)
  - runs tests
  - builds Docker image
  - pushes image to ECR/DockerHub
  - updates image tag in GitOps repo   ← CI STOPS HERE
        ↓
Git repo now has new image tag
        ↓
ArgoCD detects change (poll or webhook)
        ↓
ArgoCD compares Git vs cluster → OutOfSync
        ↓
ArgoCD applies changes → cluster updated
        ↓
New pods running with new image
```

**Key insight: CI never runs `kubectl apply`. CI only updates Git. ArgoCD does all cluster changes.**

---

## 7. Key Terms

| Term | Meaning |
|---|---|
| **Sync** | Action of making cluster match Git |
| **OutOfSync** | Cluster differs from Git |
| **Synced** | Cluster matches Git exactly |
| **Drift** | Someone manually changed cluster — now it differs from Git |
| **selfHeal** | ArgoCD automatically reverts manual cluster changes back to Git |
| **Prune** | ArgoCD deletes cluster resources when their YAML is deleted from Git |
| **Reconciliation** | The continuous loop of compare-and-fix |
| **Healthy** | Deployed resources are running correctly |
| **Degraded** | Pods crashing, deployment failing |
| **Progressing** | Rolling update in progress |

---

## 8. Status Types

### Sync Status:
- `Synced` → cluster matches Git
- `OutOfSync` → something is different

### Health Status:
- `Healthy` → all pods running, services responding
- `Degraded` → something is failing
- `Progressing` → rolling update happening

### Operation Status:
- `Succeeded` → last sync worked
- `Failed` → sync failed
- `Running` → sync in progress

---

## 9. The 4 ArgoCD YAML Objects

### Object 1: `argocd-cm` (ConfigMap)
**Job: Configure ArgoCD as a tool**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # ArgoCD public URL
  url: https://argocd.company.com

  # How often ArgoCD polls Git (default 3 min)
  timeout.reconciliation: 180s

  # SSO/OIDC login config (when using Entra ID / Okta)
  oidc.config: |
    name: Microsoft Entra ID
    issuer: https://login.microsoftonline.com/<TENANT>/v2.0
    clientID: <CLIENT_ID>
    clientSecret: $oidc.azure.clientSecret
    requestedIDTokenClaims:
      groups:
        essential: true
```

- Created **once** when setting up ArgoCD
- Owned by platform team
- Contains SSO config, URL, timeouts, behavior settings

---

### Object 2: `argocd-rbac-cm` (ConfigMap)
**Job: Control what logged-in users can do in ArgoCD**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default role for every logged-in user
  policy.default: role:readonly

  # Read groups from SSO token
  scopes: '[groups, email]'

  policy.csv: |
    # Permission rules: p, role, resource, action, scope, effect
    p, role:platform-admin,    applications, *, */*, allow
    p, role:platform-admin,    clusters,     *, *,   allow
    p, role:platform-admin,    repositories, *, *,   allow

    p, role:developer,         applications, get,  payments/*, allow
    p, role:developer,         applications, sync, payments/*, allow
    p, role:developer,         logs,         get,  payments/*, allow

    p, role:viewer,            applications, get,  */*, allow

    # Map SSO groups to roles
    g, "ARGOCD-ADMINS",        role:platform-admin
    g, "ARGOCD-DEVELOPERS",    role:developer
    g, "ARGOCD-VIEWERS",       role:viewer

    # Local admin user
    g, admin,                  role:platform-admin
```

- Created **once** when setting up ArgoCD
- Maps Entra/Okta groups to ArgoCD roles
- Controls: can user sync? view? delete? manage clusters?

**Policy line format:**
```
p,  role:name,   resource,     action,  scope,      allow/deny
p,  role:dev,    applications, sync,    payments/*, allow
```

**Actions:** `get`, `sync`, `delete`, `create`, `update`, `action`, `override`, `logs`

**Resources:** `applications`, `clusters`, `repositories`, `projects`, `accounts`, `logs`

---

### Object 3: `AppProject`
**Job: Deployment guardrails for a team**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: payments
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Payments team applications

  # Only these Git repos allowed as source
  sourceRepos:
    - https://github.com/company/payments-gitops.git

  # Only these cluster + namespace combinations allowed
  destinations:
    - namespace: payments-dev
      server: https://kubernetes.default.svc
    - namespace: payments-prod
      server: https://kubernetes.default.svc

  # Cluster-level resources allowed (global to cluster)
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace

  # Namespace-level resources allowed
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Secret
    - group: ""
      kind: Service
    - group: ""
      kind: ServiceAccount
    - group: "apps"
      kind: Deployment
    - group: "networking.k8s.io"
      kind: Ingress
    - group: "autoscaling"
      kind: HorizontalPodAutoscaler

  # Project-scoped roles (finer than global RBAC)
  roles:
    - name: deployer
      groups:
        - "PAYMENTS-DEPLOYERS"        # Entra/Okta group
      policies:
        - p, proj:payments:deployer, applications, get,  payments/*, allow
        - p, proj:payments:deployer, applications, sync, payments/*, allow
```

- Created **per team**
- Enforces: which repos, which namespaces, which resource types
- Everything NOT in the whitelist is **blocked**

---

### Object 4: `Application`
**Job: The actual deployment object — what to deploy and where**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payments-api
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # delete app = delete cluster resources
  labels:
    team: payments
    env: dev
spec:
  # Which AppProject this belongs to
  project: payments

  source:
    repoURL: https://github.com/company/payments-gitops.git
    targetRevision: main          # branch / tag / commit SHA
    path: manifests/payments/dev  # folder inside repo

  destination:
    server: https://kubernetes.default.svc
    namespace: payments-dev

  syncPolicy:
    automated:
      prune: true        # delete resources removed from Git
      selfHeal: true     # revert manual cluster changes back to Git
      allowEmpty: false  # prevent wiping cluster if path is empty

    syncOptions:
      - CreateNamespace=true   # create namespace if not exists
      - Validate=true          # validate YAML before applying

    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

- Created **per microservice** (or per environment of an app)
- You will have many of these
- Contains: Git source, destination, sync settings

---

## 10. Workload YAMLs ArgoCD Manages

These are the actual Kubernetes resources ArgoCD deploys from Git:

### Cluster-Scoped Resources (no namespace):
```
Namespace
ClusterRole
ClusterRoleBinding
StorageClass
PersistentVolume (PV)
IngressClass
GatewayClass
CustomResourceDefinition (CRD)
PriorityClass
```

### Namespace-Scoped Resources (live inside a namespace):
```
# Workloads
Deployment
StatefulSet
DaemonSet
Job
CronJob

# Networking
Service
Ingress
HTTPRoute          (Gateway API)
NetworkPolicy      (Cilium / Calico)

# Config
ConfigMap
Secret

# Storage
PersistentVolumeClaim (PVC)

# Identity
ServiceAccount
Role
RoleBinding

# Autoscaling
HorizontalPodAutoscaler (HPA)
ScaledObject            (KEDA)

# Reliability
PodDisruptionBudget (PDB)
LimitRange
ResourceQuota
```

---

## 11. RBAC — The 3 Separate Layers

```
Layer 1: ArgoCD RBAC (argocd-rbac-cm + AppProject)
  → Controls what user can do IN ArgoCD UI/CLI
  → "Can Mouli click Sync?"

Layer 2: Kubernetes RBAC (Role + RoleBinding)
  → Controls what user can do with kubectl directly
  → "Can Mouli run kubectl get pods?"

Layer 3: AWS IAM (for EKS)
  → Controls what user can do in AWS
  → "Can Mouli access EKS via AWS console?"
```

**These are completely independent. Having one does NOT give you the others.**

### Who actually deploys to Kubernetes?
```
User clicks Sync in ArgoCD
        ↓
ArgoCD checks argocd-rbac-cm → user allowed? YES
        ↓
ArgoCD checks AppProject → destination allowed? YES
        ↓
application-controller (ServiceAccount) runs kubectl apply
        ↓
Kubernetes deploys resources

NOTE: The USER never touches Kubernetes directly.
      ArgoCD's ServiceAccount does all the applying.
```

---

## 12. argocd-rbac-cm vs AppProject — Key Difference

```
argocd-rbac-cm               AppProject
─────────────────────────────────────────────────────
Subject: USER                Subject: APPLICATION
Question: can you do this?   Question: can app go here?
Controls: sync/view/delete   Controls: namespace/repo/resources
Analogy: security badge      Analogy: delivery zone rules
```

**Both must pass for deployment to happen:**
```
CHECK 1 — argocd-rbac-cm: "Does this USER have sync permission?"
                ↓ pass
CHECK 2 — AppProject: "Is this APP allowed in this namespace?"
                ↓ pass
Deployment happens
```

---

## 13. Advanced Patterns

### Sync Waves — Deploy in Order
```yaml
# Wave -1 = first (database)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"

# Wave 0 = second (API) — default
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# Wave 1 = last (smoke test)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```
ArgoCD deploys each wave and waits for it to be Healthy before moving to the next.

---

### Sync Hooks — Run Jobs at Specific Points
```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync          # runs before sync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Hook types:
- `PreSync` — before deploying (e.g. database migration)
- `Sync` — during sync
- `PostSync` — after all resources healthy (e.g. smoke test)
- `SyncFail` — only if sync fails (e.g. alert/rollback)

---

### App of Apps Pattern
One root Application manages all other Applications:
```
root-app (Application)
  └── watches: apps/ folder in Git
        ├── payments-app.yaml    → becomes Application
        ├── nginx-app.yaml       → becomes Application
        └── redis-app.yaml       → becomes Application
```
Adding a new app = create a YAML file in `apps/` folder and push to Git.

---

### Kustomize Overlays (dev/staging/prod)
```
manifests/
└── payments/
    ├── base/            # common config
    └── overlays/
        ├── dev/         # replicas=1, image=latest
        ├── staging/     # replicas=2, image=1.27
        └── prod/        # replicas=5, image=1.25 (stable)
```
Application per environment:
```yaml
source:
  path: manifests/payments/overlays/dev
```
ArgoCD auto-detects `kustomization.yaml` and runs `kustomize build`.

---

## 14. SSO / Authentication Flow

```
User opens ArgoCD UI
        ↓
argocd-server redirects to Entra ID / Okta
        ↓
User logs in with company credentials
        ↓
Identity provider returns JWT token
  (contains: user identity + group memberships)
        ↓
argocd-server validates token
        ↓
ArgoCD reads groups from token
        ↓
argocd-rbac-cm maps groups → roles
        ↓
User gets permissions based on their role
```

Groups are created in **Entra ID / Okta** — NOT in ArgoCD.
ArgoCD only reads the group names/IDs from the JWT token.

---

## 15. EKS + ArgoCD Integration

```
Human access paths:

1. ArgoCD UI login:
   User → Entra ID SSO → ArgoCD RBAC

2. Direct kubectl access to EKS:
   User → IAM Role → EKS Access Entry → K8s RBAC

3. Pod access to AWS services:
   Pod → Kubernetes ServiceAccount → IRSA → AWS API
```

These are three separate paths. Having one does NOT give you the others.

---

## 16. Creation Frequency

```
Created ONCE (platform setup):
  argocd-cm          ← tool config, SSO settings
  argocd-rbac-cm     ← global user permissions

Created PER TEAM:
  AppProject         ← guardrails for one team

Created PER MICROSERVICE:
  Application        ← one per app or per environment
```

---

## 17. Useful CLI Commands

```bash
# list all applications
argocd app list

# get detailed app status
argocd app get nginx-app

# manually sync
argocd app sync nginx-app

# sync and wait for completion
argocd app sync nginx-app --wait

# see what would change before syncing
argocd app diff nginx-app

# rollback to previous version
argocd app history nginx-app
argocd app rollback nginx-app <revision>

# pause auto-sync (useful during incident)
argocd app set nginx-app --sync-policy none

# re-enable auto-sync
argocd app set nginx-app --sync-policy automated

# hard refresh from Git (bypass cache)
argocd app get nginx-app --hard-refresh

# check if user can perform action
argocd account can-i sync applications nginx-app
```

---

## 18. Architecture Summary (One Picture)

```
                    ┌──────────────┐
                    │  Git Repo    │
                    │ (desired)    │
                    └──────┬───────┘
                           │ clone + render
                           ▼
You/UI/CLI ──► argocd-server ──► repo-server
                    │
                    │ triggers
                    ▼
              app-controller
              (reconciliation loop)
              compare Git vs K8s
                    │
                    │ kubectl apply
                    ▼
              Kubernetes API
                    │
                    ▼
              Cluster (live state)
```

---

## 19. Interview One-Liners

**What is ArgoCD?**
> ArgoCD is a GitOps continuous deployment tool for Kubernetes that continuously reconciles desired state in Git with live state in the cluster, automatically deploying changes and reverting unauthorized modifications.

**What is GitOps?**
> GitOps is a deployment approach where Git is the single source of truth — all cluster changes happen through Git commits, and a tool like ArgoCD ensures the cluster always matches what is defined in Git.

**What does the application-controller do?**
> It runs a continuous reconciliation loop, comparing desired state from Git with live state from Kubernetes, marking applications as OutOfSync when they differ, and applying changes via kubectl when auto-sync is enabled.

**Difference between argocd-rbac-cm and AppProject?**
> argocd-rbac-cm controls what a user can do inside ArgoCD (sync, view, delete). AppProject controls where an application is allowed to deploy (which namespaces, repos, resource types). Both checks must pass for a deployment to happen.

**Who actually deploys to Kubernetes?**
> ArgoCD's application-controller using its own ServiceAccount — not the user. The user only triggers the action through ArgoCD's RBAC-protected API. The controller performs the actual kubectl apply.

**What is selfHeal?**
> A sync policy setting that makes ArgoCD automatically revert any manual changes to the cluster back to the Git state, enforcing Git as the single source of truth even if someone uses kubectl directly.

**What is prune?**
> A sync policy setting that makes ArgoCD delete cluster resources when their corresponding YAML files are removed from Git, preventing orphaned resources from accumulating.

---

## 20. Resume Bullet Points

- Implemented GitOps CD pipelines using ArgoCD on Kubernetes, enabling automated deployments with Git as the single source of truth and eliminating direct cluster access from CI pipelines
- Configured ArgoCD AppProjects with namespace-level RBAC and resource whitelisting to enforce multi-team deployment isolation across dev, staging, and production environments
- Set up automated sync policies with prune and selfHeal to enforce cluster state consistency and automatically remediate configuration drift caused by manual changes
- Integrated ArgoCD with GitHub webhooks for sub-minute deployment propagation from Git push to cluster
- Implemented App of Apps pattern managing 20+ microservice deployments across multiple environments using Kustomize overlays
- Configured sync waves and PreSync hooks for ordered deployment of dependent services including zero-downtime database migrations
- Set up SSO integration with Microsoft Entra ID for ArgoCD authentication and configured group-based RBAC for platform and application team access control

---
*ArgoCD Theory Notes — 3 YOE DevOps Engineer Level*
