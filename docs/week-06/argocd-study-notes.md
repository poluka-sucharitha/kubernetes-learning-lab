# 📘 Argo CD Complete Study Notes
> Personal recall notes — covers all concepts, doubts, and clarifications from learning sessions.

---

## 📌 Table of Contents
1. [What is Argo CD?](#1-what-is-argo-cd)
2. [How Argo CD Works Internally](#2-how-argo-cd-works-internally)
3. [Argo CD Components](#3-argo-cd-components)
4. [Authentication — SSO / OIDC (Microsoft Entra)](#4-authentication--sso--oidc)
5. [Authorization — Global RBAC (argocd-rbac-cm)](#5-authorization--global-rbac)
6. [AppProject — Guardrails & Whitelisting](#6-appproject--guardrails--whitelisting)
7. [Application — Actual Deployment Object](#7-application--actual-deployment-object)
8. [Key Difference: Global RBAC vs Project RBAC](#8-key-difference-global-rbac-vs-project-rbac)
9. [Who Actually Deploys? (ServiceAccount)](#9-who-actually-deploys)
10. [Three Separate User/Access Systems (CRITICAL)](#10-three-separate-useraccess-systems)
11. [EKS kubectl Access — IAM + EKS Access Entry + K8s RBAC](#11-eks-kubectl-access)
12. [IRSA — Pod Access to AWS Services](#12-irsa--pod-access-to-aws-services)
13. [Full End-to-End Enterprise Setup (Entra + EKS + Argo CD)](#13-full-end-to-end-enterprise-setup)
14. [Whitelisting Explained](#14-whitelisting-explained)
15. [Setup Frequency — What Gets Created When](#15-setup-frequency)
16. [Final Mental Model & Interview Answers](#16-final-mental-model--interview-answers)

---

## 1. What is Argo CD?

Argo CD is a **GitOps Continuous Deployment (CD) tool for Kubernetes**.

```
Git Repo (Desired State)  ←→  Argo CD (Watcher/Deployer)  ←→  Kubernetes Cluster (Live State)
```

**Core idea:**
> Whatever is written in Git = what should be running in the cluster.

- Argo CD **continuously compares** Git state vs live cluster state.
- If they don't match → marks app as **OutOfSync**.
- In **auto-sync mode**, CI just pushes a Git change → Argo CD handles deployment automatically.

**Key Terms:**

| Term | Meaning |
|------|---------|
| Sync | Apply Git state to cluster |
| OutOfSync | Cluster doesn't match Git |
| Healthy / Degraded | App health status |
| Prune | Delete resources removed from Git |
| Self-heal | Fix drift caused by manual cluster changes |

---

## 2. How Argo CD Works Internally

### CI/CD Flow
```
Developer changes code
   ↓
CI builds image, pushes image tag
   ↓
CI updates GitOps repo with new image tag
   ↓
Argo CD detects Git change
   ↓
Argo CD syncs to cluster
```

### Internal Component Flow
```
Git Repo
   ↓
repo-server (clones Git, renders Helm/Kustomize/plain YAML)
   ↓
application-controller (compares desired vs live state)
   ↓
Kubernetes API
   ↓
Cluster (actual running state)
```

---

## 3. Argo CD Components

| Component | What It Does |
|-----------|-------------|
| `argocd-server` | Exposes UI, CLI, Auth (SSO/OIDC), RBAC enforcement |
| `repo-server` | Clones Git repo, renders Helm charts / Kustomize / plain YAML |
| `application-controller` | Core brain — compares desired vs live, triggers sync |

> **argocd-server** = where users interact  
> **repo-server** = where manifests come from  
> **application-controller** = where actual deploy decisions happen

---

## 4. Authentication — SSO / OIDC

### Key Concept
> ❗ Argo CD does NOT manage users. Users exist in your Identity Provider (IdP).

**Supported IdPs:** Microsoft Entra ID, Okta, Keycloak, Google

### Login Flow
```
User opens Argo CD UI
   ↓
Redirected to Entra/Okta login
   ↓
User authenticates
   ↓
IdP returns JWT token (with groups claim)
   ↓
argocd-server validates token
   ↓
RBAC checks groups/roles
   ↓
Access allowed or denied
```

### `argocd-cm` — SSO Configuration

> **Purpose:** Configure Argo CD itself — URL, OIDC/SSO settings, general behavior.  
> ❗ This is NOT where you define permissions. It's for authentication setup.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.company.com
  oidc.config: |
    name: Microsoft Entra ID
    issuer: https://login.microsoftonline.com/<TENANT_ID>/v2.0
    clientID: <CLIENT_ID>
    clientSecret: $oidc.azure.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
    requestedIDTokenClaims:
      groups:
        essential: true   # ← This requests group membership from Entra in the token
```

### `argocd-secret` — Store Client Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  oidc.azure.clientSecret: "<CLIENT_SECRET_FROM_ENTRA>"
```

### Entra Side — What You Need to Do

```
1. Create Entra App Registration for Argo CD
   - Add API permission: User.Read
   - Add Groups claim in Token Configuration

2. Create Security Groups:
   - ARGOCD-PLATFORM-ADMINS
   - ARGOCD-PAYMENTS-DEPLOYERS
   - ARGOCD-PAYMENTS-VIEWERS

3. Add users to groups:
   - Ravi  → ARGOCD-PLATFORM-ADMINS
   - Mouli → ARGOCD-PAYMENTS-DEPLOYERS
   - Anita → ARGOCD-PAYMENTS-VIEWERS

4. Assign groups to Enterprise Application:
   Entra → Enterprise Applications → Argo CD → Users and Groups → Add
```

> **Production tip:** Use Entra Group **Object IDs** (GUIDs) in Argo CD RBAC, not display names. Display names can change; GUIDs are stable.

---

## 5. Authorization — Global RBAC

### `argocd-rbac-cm` — Global Argo CD Permissions

> **Purpose:** Define **what actions** logged-in users can perform in Argo CD globally.  
> This controls: can they view apps? sync apps? manage clusters? manage repos?

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly     # ← Everyone who logs in gets read-only by default
  scopes: '[groups, email]'
  policy.csv: |
    # ---- Platform Admin (full access) ----
    p, role:platform-admin, applications, *, */*, allow
    p, role:platform-admin, clusters,     *, *,    allow
    p, role:platform-admin, repositories, *, *,    allow
    p, role:platform-admin, projects,     *, *,    allow
    p, role:platform-admin, logs,         get, */*, allow

    # ---- Payments Deployer ----
    p, role:payments-deployer, applications, get,  payments/*, allow
    p, role:payments-deployer, applications, sync, payments/*, allow
    p, role:payments-deployer, logs,         get,  payments/*, allow

    # ---- Payments Viewer ----
    p, role:payments-viewer, applications, get, payments/*, allow
    p, role:payments-viewer, logs,         get, payments/*, allow

    # ---- Map Entra Group IDs → Roles ----
    g, "11111111-1111-1111-1111-111111111111", role:platform-admin
    g, "22222222-2222-2222-2222-222222222222", role:payments-deployer
    g, "33333333-3333-3333-3333-333333333333", role:payments-viewer
```

**Policy line format:**
```
p, <role>, <resource>, <action>, <scope>, allow/deny
g, <entra-group-id>, <role>
```

---

## 6. AppProject — Guardrails & Whitelisting

> **Purpose:** Restrict WHERE apps can deploy and WHAT resources they can create.  
> Think of it as a security boundary for a team.

### AppProject = Security Guard

| What AppProject Controls | Example |
|--------------------------|---------|
| Which Git repos allowed | only `payments-gitops.git` |
| Which clusters/namespaces allowed | only `payments-dev`, `payments-prod` |
| Which K8s resource kinds allowed | only `Deployment`, `Service`, `ConfigMap` |
| Project-scoped roles | `deployer` role only for payments project |

### Full AppProject Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: payments
  namespace: argocd
spec:
  description: Payments team project

  # ✅ ONLY this Git repo is allowed as source
  sourceRepos:
    - https://github.com/company/payments-gitops.git

  # ✅ ONLY these namespaces/clusters allowed as destinations
  destinations:
    - namespace: payments-dev
      server: https://kubernetes.default.svc
    - namespace: payments-prod
      server: https://kubernetes.default.svc

  # ✅ Cluster-level resources this project can create
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace

  # ✅ Namespace-level resources this project can create
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Secret
    - group: ""
      kind: Service
    - group: "apps"
      kind: Deployment
    - group: "networking.k8s.io"
      kind: Ingress

  # ✅ Project-scoped roles (fine-grained per-team)
  roles:
    - name: deployer
      description: Payments team deployers
      groups:
        - 22222222-2222-2222-2222-222222222222   # ARGOCD-PAYMENTS-DEPLOYERS
      policies:
        - p, proj:payments:deployer, applications, get,  payments/*, allow
        - p, proj:payments:deployer, applications, sync, payments/*, allow
        - p, proj:payments:deployer, logs,         get,  payments/*, allow

    - name: viewer
      description: Payments team viewers
      groups:
        - 33333333-3333-3333-3333-333333333333   # ARGOCD-PAYMENTS-VIEWERS
      policies:
        - p, proj:payments:viewer, applications, get, payments/*, allow
        - p, proj:payments:viewer, logs,         get, payments/*, allow
```

### Whitelisting Behavior

```
Mouli (Payments Deployer) tries:
  ✅ Deploy Deployment to payments-dev  → ALLOWED
  ❌ Deploy to default namespace        → BLOCKED (destination not permitted)
  ❌ Create ClusterRole                 → BLOCKED (not in whitelist)
  ❌ Delete app                         → BLOCKED (no delete permission in RBAC)
```

---

## 7. Application — Actual Deployment Object

> **Purpose:** Tells Argo CD WHAT to deploy and WHERE. This is the actual CD pipeline object.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payments-api
  namespace: argocd
spec:
  project: payments          # ← Must follow this project's rules

  source:
    repoURL: https://github.com/company/payments-gitops.git
    targetRevision: main
    path: apps/payments-api/overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: payments-dev

  syncPolicy:
    automated:
      prune: true       # ← Remove resources deleted from Git
      selfHeal: true    # ← Fix drift if someone manually changes cluster
```

### Multiple Apps Under One Project

```
AppProject: payments
  ├── Application: payments-api-dev
  ├── Application: payments-ui-dev
  ├── Application: payments-worker-dev
  ├── Application: payments-api-prod
  └── Application: payments-ui-prod
```

---

## 8. Key Difference: Global RBAC vs Project RBAC

| Feature | Global RBAC (`argocd-rbac-cm`) | Project RBAC (`AppProject.roles`) |
|---------|-------------------------------|----------------------------------|
| Scope | Entire Argo CD | Single project only |
| Controls | Platform-level actions | Project-scoped actions |
| Used for | Platform admins, org-wide readonly | App team deployers/viewers |
| Role format | `role:<name>` | `proj:<project>:<role>` |

### The Combined Effect

```
Global RBAC answers:  "Can this user sync in Argo CD?"
Project RBAC answers: "Can this user sync THIS project?"
AppProject answers:   "Can THIS app go to THIS namespace?"
```

> **Best practice:**  
> - Global RBAC → for platform-admin, org-wide readonly  
> - Project RBAC → for app-team isolation per project

---

## 9. Who Actually Deploys?

> ❗ Users do NOT directly deploy to Kubernetes. Argo CD's controller does.

```
User clicks "Sync" in UI
   ↓
argocd-server checks RBAC (is user allowed?)
   ↓
application-controller (ServiceAccount)
   ↓
Kubernetes API
   ↓
Resources created/updated in cluster
```

### Default ServiceAccounts Created at Install

```bash
kubectl get sa -n argocd

# Output includes:
# argocd-application-controller  ← This is what deploys everything
# argocd-server
# argocd-repo-server
```

The `argocd-application-controller` has a `ClusterRole` with near-admin access by default.

> **Production note:** In strict environments, restrict this ClusterRole or use namespace-scoped Argo CD installs.

---

## 10. Three Separate User/Access Systems

> ❗ **CRITICAL — Don't mix these up. They serve different purposes.**

| System | Purpose | Used Where |
|--------|---------|-----------|
| SSO Users (Entra/Okta) | Login to Argo CD UI/CLI | Argo CD |
| AWS IAM | Access AWS APIs, EKS authentication | AWS / EKS |
| Kubernetes RBAC (ServiceAccount) | Control what pods/tools can do in cluster | Kubernetes |

### Full Architecture
```
Human login to Argo CD:
  User → Entra/Okta (SSO) → Argo CD RBAC → Argo CD UI

Direct kubectl to EKS:
  User/IAM Role → EKS Access Entry → Kubernetes RBAC → kubectl

Pod access to AWS:
  Pod → Kubernetes ServiceAccount → IRSA IAM Role → AWS APIs
```

---

## 11. EKS kubectl Access

> For humans who need `kubectl` access to EKS (NOT for Argo CD UI login — that's separate).

### The Chain
```
IAM Role/User
   ↓
EKS Access Entry (tells EKS to recognize this IAM identity)
   ↓
Kubernetes Group mapping
   ↓
Kubernetes Role + RoleBinding (decides what they can do)
```

### Step 1 — Create EKS Access Entry

```bash
aws eks create-access-entry \
  --cluster-name prod-cluster \
  --principal-arn arn:aws:iam::123456789012:role/dev-eks-readonly \
  --kubernetes-groups payments-readonly
```

> This tells EKS: "When this IAM role authenticates, treat them as Kubernetes group `payments-readonly`"

### Step 2 — Create Kubernetes Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: payments-readonly-role
  namespace: payments
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
```

### Step 3 — Bind Group to Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payments-readonly-binding
  namespace: payments
subjects:
  - kind: Group
    name: payments-readonly        # ← Matches the kubernetes-group from access entry
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: payments-readonly-role
  apiGroup: rbac.authorization.k8s.io
```

### Result

```
Ravi assumes IAM role dev-eks-readonly
   ↓
EKS recognizes it, maps to group "payments-readonly"
   ↓
RoleBinding attaches "payments-readonly" to readonly Role
   ↓
Ravi can: kubectl get pods -n payments ✅
Ravi cannot: kubectl delete deploy ... ❌
```

### Old Way vs New Way

| Approach | Status |
|----------|--------|
| `aws-auth` ConfigMap | Older — still works but not recommended for new setups |
| EKS Access Entries | ✅ Current recommended approach |

---

## 12. IRSA — Pod Access to AWS Services

> For workloads inside Kubernetes that need to call AWS APIs (S3, Secrets Manager, RDS, etc.)

### The Chain
```
Pod
 ↓
Kubernetes ServiceAccount (annotated with IAM role ARN)
 ↓
IRSA — EKS injects AWS credentials into pod
 ↓
AWS APIs (S3, Secrets Manager, SQS, RDS, etc.)
```

### ServiceAccount with IRSA Annotation

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payments-sa
  namespace: payments-prod
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/payments-app-irsa-role
```

### Deployment Using That ServiceAccount

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  namespace: payments-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payments-api
  template:
    metadata:
      labels:
        app: payments-api
    spec:
      serviceAccountName: payments-sa    # ← Use the IRSA-enabled SA
      containers:
        - name: api
          image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/payments-api:v1
```

> **Key point:** No static AWS keys. No secrets stored in YAML. IRSA handles it via IAM role assumption.

---

## 13. Full End-to-End Enterprise Setup

### Scenario
- EKS cluster: `prod-cluster`
- Argo CD at: `https://argocd.company.com`
- Identity: Microsoft Entra ID
- Team: Payments (3 people)

### Entra Groups → Users

| Group Name | Users | Entra Object ID |
|-----------|-------|----------------|
| ARGOCD-PLATFORM-ADMINS | Ravi | `11111111-...` |
| ARGOCD-PAYMENTS-DEPLOYERS | Mouli | `22222222-...` |
| ARGOCD-PAYMENTS-VIEWERS | Anita | `33333333-...` |

### argocd-cm (SSO Config)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.company.com
  oidc.config: |
    name: Microsoft Entra ID
    issuer: https://login.microsoftonline.com/<TENANT_ID>/v2.0
    clientID: <CLIENT_ID>
    clientSecret: $oidc.azure.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
    requestedIDTokenClaims:
      groups:
        essential: true
```

### argocd-rbac-cm (Global Permissions)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  scopes: '[groups, email]'
  policy.csv: |
    p, role:platform-admin,      applications, *, */*, allow
    p, role:platform-admin,      clusters,     *, *,    allow
    p, role:platform-admin,      repositories, *, *,    allow
    p, role:platform-admin,      projects,     *, *,    allow

    p, role:payments-deployer,   applications, get,  payments/*, allow
    p, role:payments-deployer,   applications, sync, payments/*, allow
    p, role:payments-deployer,   logs,         get,  payments/*, allow

    p, role:payments-viewer,     applications, get,  payments/*, allow
    p, role:payments-viewer,     logs,         get,  payments/*, allow

    g, "11111111-1111-1111-1111-111111111111", role:platform-admin
    g, "22222222-2222-2222-2222-222222222222", role:payments-deployer
    g, "33333333-3333-3333-3333-333333333333", role:payments-viewer
```

### AppProject (Payments Guardrails)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: payments
  namespace: argocd
spec:
  description: Payments team project
  sourceRepos:
    - https://github.com/company/payments-gitops.git
  destinations:
    - namespace: payments-dev
      server: https://kubernetes.default.svc
    - namespace: payments-prod
      server: https://kubernetes.default.svc
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Secret
    - group: ""
      kind: Service
    - group: "apps"
      kind: Deployment
    - group: "networking.k8s.io"
      kind: Ingress
  roles:
    - name: deployer
      groups:
        - 22222222-2222-2222-2222-222222222222
      policies:
        - p, proj:payments:deployer, applications, get,  payments/*, allow
        - p, proj:payments:deployer, applications, sync, payments/*, allow
    - name: viewer
      groups:
        - 33333333-3333-3333-3333-333333333333
      policies:
        - p, proj:payments:viewer, applications, get, payments/*, allow
```

### Application (One Microservice)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payments-api
  namespace: argocd
spec:
  project: payments
  source:
    repoURL: https://github.com/company/payments-gitops.git
    targetRevision: main
    path: apps/payments-api/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: payments-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Full Login Flow

```
Ravi opens https://argocd.company.com
   ↓
Redirected to Microsoft Entra login
   ↓
Entra authenticates, returns JWT with groups claim
   ↓
argocd-server reads group: ARGOCD-PLATFORM-ADMINS
   ↓
argocd-rbac-cm maps it to role:platform-admin
   ↓
Ravi can manage all Argo CD resources

---

Mouli logs in → group: ARGOCD-PAYMENTS-DEPLOYERS
   ↓
argocd-rbac-cm → role:payments-deployer
   ↓
Can sync payments/* apps only

Mouli tries to deploy to "default" namespace:
   ↓
AppProject checks destination
   ↓
❌ BLOCKED — not in allowed destinations

---

Anita logs in → group: ARGOCD-PAYMENTS-VIEWERS
   ↓
Can only view payments apps and logs ✅
Cannot sync ❌
```

---

## 14. Whitelisting Explained

> **Whitelist = ONLY these things are allowed. Everything else = DENIED.**

### Two Types of Whitelisting in AppProject

| Type | Controls |
|------|---------|
| `destinations` | WHERE apps can deploy (namespace + cluster) |
| `namespaceResourceWhitelist` | WHAT resource kinds can be created inside namespace |
| `clusterResourceWhitelist` | WHAT cluster-level resources can be created |

### Allowed vs Blocked Matrix

```
Destination:
  ✅ namespace: payments-dev  → ALLOWED
  ✅ namespace: payments-prod → ALLOWED
  ❌ namespace: default       → BLOCKED
  ❌ namespace: kube-system   → BLOCKED
  ❌ namespace: hr-dev        → BLOCKED

Resources:
  ✅ kind: Deployment         → ALLOWED (in whitelist)
  ✅ kind: Service            → ALLOWED (in whitelist)
  ❌ kind: ClusterRole        → BLOCKED (not in whitelist)
  ❌ kind: StatefulSet        → BLOCKED (not in whitelist)
  ❌ kind: DaemonSet          → BLOCKED (not in whitelist)
```

---

## 15. Setup Frequency

| Object | Created | By Whom |
|--------|---------|---------|
| `argocd-cm` | Once (initial setup) | Platform team |
| `argocd-rbac-cm` | Once (updated when new teams join) | Platform team |
| `AppProject` | Per team or security boundary | Platform team |
| `Application` | Per microservice / per environment | App team or platform |

### Typical Folder Structure

```
gitops-repo/
├── argocd-config/
│   ├── argocd-cm.yaml
│   ├── argocd-rbac-cm.yaml
│   └── argocd-secret.yaml
├── projects/
│   └── payments-project.yaml
└── apps/
    ├── payments-api-dev.yaml
    ├── payments-ui-dev.yaml
    ├── payments-worker-dev.yaml
    ├── payments-api-prod.yaml
    └── payments-ui-prod.yaml
```

---

## 16. Final Mental Model & Interview Answers

### The 4-Object Argo CD Setup

```
argocd-cm          = HOW users log in (SSO/OIDC config)
argocd-rbac-cm     = WHAT users can do globally in Argo CD
AppProject         = WHERE apps can deploy + resource guardrails
Application        = WHAT app Argo CD should deploy
```

### The 3 Access Systems (Never Mix These)

```
SSO (Entra/Okta)   → Argo CD UI access
IAM + EKS Entry    → kubectl access to EKS
IRSA               → Pod access to AWS services
```

### Permissions Layering

```
Entra → WHO the user is
RBAC  → WHAT the user can do
Project → WHERE the app can go
```

### Interview-Ready Answers

**Q: How does Argo CD authentication work in production?**
> In production, Argo CD authentication is integrated with an enterprise OIDC provider like Microsoft Entra ID or Okta. Users log in via SSO, and their group membership in the JWT token is used for RBAC authorization. Argo CD itself does not manage users.

**Q: What is the difference between Global RBAC and Project RBAC?**
> Global RBAC in `argocd-rbac-cm` defines platform-wide permissions such as managing applications, repositories, and clusters. Project RBAC in `AppProject.roles` provides fine-grained, project-scoped access for application teams. In production, global RBAC handles platform-level roles and Project RBAC handles team isolation.

**Q: Who actually deploys when a user clicks Sync?**
> Users do not deploy directly. The `argocd-application-controller`, running with its own ServiceAccount and cluster permissions, interacts with the Kubernetes API to apply resources. Users only trigger actions through the Argo CD API, which enforces RBAC before allowing the controller to act.

**Q: How do you give a developer kubectl access to EKS?**
> The developer authenticates using an AWS IAM role. An EKS Access Entry maps that IAM role to a Kubernetes group. A Kubernetes RoleBinding then attaches that group to a Role with the specific permissions needed. IAM proves identity; EKS lets them into the cluster; Kubernetes RBAC decides what they can do inside.

**Q: How do pods access AWS services securely?**
> Using IRSA (IAM Roles for Service Accounts). The pod uses a Kubernetes ServiceAccount annotated with an IAM role ARN. EKS injects temporary AWS credentials via a projected volume, so the pod assumes the IAM role without any static credentials.

---

*End of Study Notes — Argo CD + EKS + SSO + RBAC*
