# ArgoCD Complete Hands-On Lab — Production Grade
### From Zero to GitOps on KIND Cluster

---

## What You Will Have After This Lab

- ArgoCD installed and running on KIND
- A real GitOps repo structure (like production)
- An Application that watches Git and auto-deploys
- Drift detection + auto self-heal working
- AppProject with namespace restrictions
- RBAC configured
- You will understand every YAML line — resume-ready

---

## Mental Model Before Starting

```
Git Repo  ──►  ArgoCD  ──►  Kubernetes Cluster
(desired)       (engine)       (live state)

If Git ≠ Cluster  →  ArgoCD marks as OutOfSync
If auto-sync ON   →  ArgoCD applies Git to Cluster
If someone edits cluster manually  →  selfHeal fixes it
```

---

## Lab Folder Structure

Create this folder structure on your machine. This simulates a real company GitOps repo.

```
argocd-lab/
├── apps/                          # ArgoCD Application YAMLs
│   ├── nginx-app.yaml
│   └── appproject-payments.yaml
├── manifests/                     # Actual K8s manifests (what gets deployed)
│   └── nginx/
│       ├── namespace.yaml
│       ├── deployment.yaml
│       └── service.yaml
└── argocd-config/                 # ArgoCD platform config
    ├── argocd-cm.yaml
    └── argocd-rbac-cm.yaml
```

Run this to create it:

```bash
mkdir -p argocd-lab/{apps,manifests/nginx,argocd-config}
cd argocd-lab
git init
```

---

## STEP 1 — Install ArgoCD on KIND

### 1.1 Verify KIND cluster is running

```bash
kubectl cluster-info
kubectl get nodes
```

Expected output:
```
NAME                 STATUS   ROLES           AGE
kind-control-plane   Ready    control-plane   2m
```

### 1.2 Create ArgoCD namespace and install

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 1.3 Wait for all pods to be Running

```bash
kubectl get pods -n argocd -w
```

Wait until you see all pods Running (takes 2-3 minutes):
```
argocd-application-controller-0          1/1   Running
argocd-dex-server-xxx                    1/1   Running
argocd-redis-xxx                         1/1   Running
argocd-repo-server-xxx                   1/1   Running
argocd-server-xxx                        1/1   Running
```

### 1.4 Expose ArgoCD UI (port-forward for local)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open browser: https://localhost:8080  
Accept the certificate warning (self-signed in local).

### 1.5 Get the initial admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Login: **admin** / (password from above command)

### 1.6 Install ArgoCD CLI

```bash
# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login via CLI
argocd login localhost:8080 --username admin --password <password> --insecure
```

---

## STEP 2 — Create Your GitOps Repo

In production this is a private GitHub/GitLab repo.  
For this lab, use a public GitHub repo or a local path.

**Option A: GitHub (recommended — shows real GitOps)**

1. Create a new repo on GitHub: `argocd-lab`
2. Push your local folder:

```bash
cd argocd-lab
git remote add origin https://github.com/<your-username>/argocd-lab.git
git branch -M main
git push -u origin main
```

**Option B: Local path (quick start)**

For a fully local setup (no GitHub needed):

```bash
# ArgoCD can read from a local path in KIND
# We'll use GitHub in this guide for realism
```

---

## STEP 3 — Create K8s Manifests (What Gets Deployed)

These go inside `manifests/nginx/`. These are the actual resources ArgoCD will deploy.

### File: `manifests/nginx/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-dev
  labels:
    env: dev
    team: platform
```

### File: `manifests/nginx/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: nginx-dev
  labels:
    app: nginx
    version: "1.0"
    managed-by: argocd
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        version: "1.0"
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 15
```

**Why these fields matter in production:**
- `resources.requests/limits` — required in every production deployment, prevents pod OOM
- `readinessProbe` — tells K8s when pod is ready to receive traffic
- `livenessProbe` — tells K8s to restart pod if it stops responding
- `managed-by: argocd` label — easy to filter ArgoCD-managed resources

### File: `manifests/nginx/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: nginx-dev
  labels:
    app: nginx
    managed-by: argocd
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

---

## STEP 4 — Create the AppProject

AppProject = guardrails. Before creating any Application, define which repos and namespaces are allowed.

### File: `apps/appproject-payments.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
  # finalizer prevents accidental deletion when apps are using it
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: Platform team applications - dev and staging workloads

  # ONLY these Git repos can be used as source
  # In production: replace with your actual org repos
  sourceRepos:
    - https://github.com/<your-username>/argocd-lab.git
    - https://github.com/<your-username>/*     # allow all repos in your org

  # ONLY these cluster+namespace combinations are allowed as destinations
  destinations:
    - namespace: nginx-dev
      server: https://kubernetes.default.svc    # same cluster where ArgoCD runs
    - namespace: nginx-staging
      server: https://kubernetes.default.svc

  # Cluster-level resources this project is allowed to manage
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace                            # allow creating namespaces

  # Namespace-level resources this project is allowed to manage
  # Everything NOT listed here is BLOCKED
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
    - group: "apps"
      kind: ReplicaSet
    - group: "networking.k8s.io"
      kind: Ingress
    - group: "autoscaling"
      kind: HorizontalPodAutoscaler

  # Optional: project-level roles (for team access control)
  roles:
    - name: developer
      description: Platform team developers
      policies:
        - p, proj:platform:developer, applications, get, platform/*, allow
        - p, proj:platform:developer, applications, sync, platform/*, allow
      groups:
        - platform-developers         # Entra/Okta group name or ID
```

Apply it:

```bash
kubectl apply -f apps/appproject-payments.yaml
```

Verify:

```bash
kubectl get appproject -n argocd
argocd proj list
```

---

## STEP 5 — Create the ArgoCD Application

This is the core GitOps object. It tells ArgoCD: "Watch this Git path, deploy to this namespace."

### File: `apps/nginx-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
  # This finalizer means: when you delete this Application,
  # also delete all resources it created in the cluster
  # IMPORTANT in production — prevents orphaned resources
  finalizers:
    - resources-finalizer.argocd.argoproj.io

  # Labels for organizing apps in ArgoCD UI
  labels:
    team: platform
    env: dev
    app: nginx

spec:
  # Which AppProject this Application belongs to
  # It MUST follow that project's sourceRepos + destinations rules
  project: platform

  source:
    # Your GitOps repo URL
    repoURL: https://github.com/<your-username>/argocd-lab.git

    # Branch, tag, or commit SHA to track
    # In production: pin to a tag for prod, use branch for dev
    targetRevision: main

    # Path inside the repo where K8s manifests are
    path: manifests/nginx

  destination:
    # For same-cluster deployment (most common)
    server: https://kubernetes.default.svc
    namespace: nginx-dev

  syncPolicy:
    automated:
      # prune: true means — if you DELETE a file from Git,
      # ArgoCD will also DELETE that resource from the cluster
      # Without this: deleted files in Git leave resources running forever
      prune: true

      # selfHeal: true means — if someone manually changes the cluster
      # (kubectl edit, kubectl scale, etc.), ArgoCD will REVERT it back to Git
      # This is the core of GitOps enforcement
      selfHeal: true

      # allowEmpty: false prevents ArgoCD from wiping everything
      # if the path accidentally becomes empty in Git
      allowEmpty: false

    syncOptions:
      # Creates namespace if it doesn't exist
      - CreateNamespace=true

      # Uses server-side apply instead of kubectl apply
      # Better for large manifests and CRDs in production
      - ServerSideApply=false

      # If any resource fails to sync, stop — don't apply rest
      # Prevents partial deployments
      - Validate=true

    # Retry logic — important for production
    # If sync fails (e.g. image pull error), retry with backoff
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

Commit and push, then apply:

```bash
git add .
git commit -m "add nginx manifests and argocd app"
git push

kubectl apply -f apps/nginx-app.yaml
```

---

## STEP 6 — Watch ArgoCD Detect and Sync

### Check application status via CLI

```bash
argocd app list
```

Output:
```
NAME        CLUSTER    NAMESPACE  PROJECT   STATUS  HEALTH   SYNCPOLICY  CONDITIONS
nginx-app   in-cluster nginx-dev  platform  Synced  Healthy  Auto-Prune  <none>
```

### Get detailed status

```bash
argocd app get nginx-app
```

### Watch sync happen in real time

```bash
argocd app sync nginx-app --watch
```

### Check resources deployed

```bash
kubectl get all -n nginx-dev
```

Expected:
```
NAME                                    READY   STATUS    RESTARTS
pod/nginx-deployment-xxx-yyy            1/1     Running   0
pod/nginx-deployment-xxx-zzz            1/1     Running   0

NAME                    TYPE        CLUSTER-IP    PORT(S)
service/nginx-service   ClusterIP   10.96.x.x     80/TCP

NAME                               READY   UP-TO-DATE   AVAILABLE
deployment.apps/nginx-deployment   2/2     2            2
```

---

## STEP 7 — Test GitOps: Change Git and Watch ArgoCD React

This is the core of GitOps. Make a change in Git — ArgoCD detects and deploys.

### Test 1: Scale replicas via Git

Edit `manifests/nginx/deployment.yaml` — change `replicas: 2` to `replicas: 3`

```bash
# Edit the file
sed -i 's/replicas: 2/replicas: 3/' manifests/nginx/deployment.yaml

# Push to Git
git add manifests/nginx/deployment.yaml
git commit -m "scale nginx to 3 replicas"
git push
```

By default ArgoCD polls every 3 minutes.  
To trigger immediately:

```bash
argocd app sync nginx-app
```

Verify:

```bash
kubectl get pods -n nginx-dev
# You should now see 3 pods
```

### Test 2: Update image version

Edit `manifests/nginx/deployment.yaml` — change `image: nginx:1.25` to `image: nginx:1.27`

```bash
git add .
git commit -m "upgrade nginx image to 1.27"
git push
argocd app sync nginx-app
```

Watch rolling update:

```bash
kubectl rollout status deployment/nginx-deployment -n nginx-dev
```

### Test 3: Test drift detection and self-heal (IMPORTANT)

This shows why `selfHeal: true` matters in production.

```bash
# Manually scale down the deployment (simulates someone doing kubectl in production)
kubectl scale deployment nginx-deployment -n nginx-dev --replicas=1

# Check what ArgoCD sees
kubectl get pods -n nginx-dev
# Shows 1 pod — but Git says 3

# Wait a few seconds — or check ArgoCD status
argocd app get nginx-app
# Status will show: OutOfSync

# selfHeal kicks in automatically and restores 3 replicas
# Watch it recover:
kubectl get pods -n nginx-dev -w
```

Within 30-60 seconds ArgoCD will self-heal back to 3 replicas.

### Test 4: Test prune (delete a resource via Git)

```bash
# Delete the service from Git
rm manifests/nginx/service.yaml
git add .
git commit -m "remove nginx service"
git push

argocd app sync nginx-app

# Verify service is deleted from cluster
kubectl get svc -n nginx-dev
# Should show: No resources found
```

This is `prune: true` in action — Git is source of truth.

---

## STEP 8 — Configure ArgoCD Platform Settings

### File: `argocd-config/argocd-cm.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Public URL of your ArgoCD server
  url: https://argocd.company.com          # change to your URL

  # How often ArgoCD polls Git for changes (default: 3 min)
  # In production: keep at 3m, or use Git webhooks for instant sync
  timeout.reconciliation: 180s

  # Allow applications to be created in any namespace
  # (not just argocd namespace) — useful for multi-team setups
  application.instanceLabelKey: argocd.argoproj.io/app-name

  # Resource tracking method — annotation is most reliable
  application.resourceTrackingMethod: annotation

  # For SSO (uncomment and fill when you have Entra/Okta)
  # url: https://argocd.company.com
  # oidc.config: |
  #   name: Microsoft Entra ID
  #   issuer: https://login.microsoftonline.com/<TENANT_ID>/v2.0
  #   clientID: <CLIENT_ID>
  #   clientSecret: $oidc.azure.clientSecret
  #   requestedScopes:
  #     - openid
  #     - profile
  #     - email
  #   requestedIDTokenClaims:
  #     groups:
  #       essential: true
```

### File: `argocd-config/argocd-rbac-cm.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default role for ALL logged-in users
  # readonly = can see everything but cannot change anything
  policy.default: role:readonly

  # Scopes to read from JWT token
  # groups = read group membership from SSO token
  scopes: '[groups, email]'

  policy.csv: |
    # ─── PLATFORM ADMIN ───────────────────────────────────────────
    # Can do everything in ArgoCD
    p, role:platform-admin, applications,  *, */*, allow
    p, role:platform-admin, clusters,      *, *,   allow
    p, role:platform-admin, repositories,  *, *,   allow
    p, role:platform-admin, projects,      *, *,   allow
    p, role:platform-admin, accounts,      *, *,   allow
    p, role:platform-admin, logs,          get, */*, allow

    # ─── PLATFORM DEVELOPER ───────────────────────────────────────
    # Can view and sync apps but cannot manage clusters/repos
    p, role:platform-developer, applications, get,    */*, allow
    p, role:platform-developer, applications, sync,   */*, allow
    p, role:platform-developer, applications, action, */*, allow
    p, role:platform-developer, logs,         get,    */*, allow

    # ─── READ ONLY ────────────────────────────────────────────────
    # Can view everything — good for managers / auditors
    p, role:viewer, applications, get, */*, allow
    p, role:viewer, logs,         get, */*, allow

    # ─── GROUP MAPPINGS (SSO) ─────────────────────────────────────
    # Map Entra/Okta group IDs to ArgoCD roles
    # Replace GUIDs with your real Entra group Object IDs
    g, "ARGOCD-PLATFORM-ADMINS",    role:platform-admin
    g, "ARGOCD-PLATFORM-DEVS",      role:platform-developer
    g, "ARGOCD-VIEWERS",            role:readonly

    # For local users (before SSO is configured)
    g, admin, role:platform-admin
```

Apply these configs:

```bash
kubectl apply -f argocd-config/argocd-cm.yaml
kubectl apply -f argocd-config/argocd-rbac-cm.yaml

# Restart argocd-server to pick up changes
kubectl rollout restart deployment argocd-server -n argocd
```

---

## STEP 9 — Git Webhook (Make Sync Instant)

By default ArgoCD polls every 3 minutes. In production you configure a webhook so ArgoCD syncs the moment you push to Git.

### GitHub Webhook Setup

1. Go to your GitHub repo → Settings → Webhooks → Add webhook
2. Payload URL: `https://argocd.company.com/api/webhook`
3. Content type: `application/json`
4. Secret: generate a random string
5. Events: Just the push event

Then add the secret to ArgoCD:

```bash
kubectl -n argocd patch secret argocd-secret \
  --type merge \
  --patch '{"stringData": {"webhook.github.secret": "your-webhook-secret"}}'
```

Now every `git push` triggers ArgoCD sync in seconds — no 3-minute wait.

---

## STEP 10 — Production Patterns to Know

### Pattern 1: App of Apps

In production you don't manually apply each Application YAML. You create ONE root Application that manages all other Applications. This is called App of Apps.

```
root-app (Application)
  └── watches: apps/ folder in Git
        ├── nginx-app.yaml      → becomes Application
        ├── payments-app.yaml   → becomes Application
        └── redis-app.yaml      → becomes Application
```

### File: `apps/root-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/argocd-lab.git
    targetRevision: main
    path: apps               # This folder contains other Application YAMLs
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd        # Applications land in argocd namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Now adding a new app is just: create a YAML in `apps/` folder and push to Git. ArgoCD detects it and creates the Application automatically.

### Pattern 2: Kustomize Overlays (dev/staging/prod)

Real production repos use Kustomize to manage environment differences.

```
manifests/nginx/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml      # patches: replicas=1, image=nginx:latest
    │   └── replica-patch.yaml
    ├── staging/
    │   ├── kustomization.yaml      # patches: replicas=2, image=nginx:1.27
    │   └── replica-patch.yaml
    └── prod/
        ├── kustomization.yaml      # patches: replicas=5, image=nginx:1.25 (stable)
        └── replica-patch.yaml
```

Application for dev environment:

```yaml
spec:
  source:
    repoURL: https://github.com/<your-username>/argocd-lab.git
    targetRevision: main
    path: manifests/nginx/overlays/dev   # ArgoCD auto-detects kustomization.yaml
```

ArgoCD natively runs `kustomize build` — no plugin needed.

### Pattern 3: Helm Charts

```yaml
spec:
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.x.x
    helm:
      releaseName: nginx
      values: |
        replicaCount: 3
        service:
          type: ClusterIP
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
```

Or override from a values file in Git:

```yaml
spec:
  source:
    repoURL: https://github.com/<your-username>/argocd-lab.git
    targetRevision: main
    path: charts/nginx
    helm:
      valueFiles:
        - values-dev.yaml
```

### Pattern 4: Sync Waves (Deploy in Order)

When you have dependencies (e.g. database must come up before API), use sync waves.

```yaml
# Deploy database first (wave -1)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  annotations:
    argocd.argoproj.io/sync-wave: "-1"    # negative = earlier

---
# Deploy API after database (wave 0, default)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-api
  annotations:
    argocd.argoproj.io/sync-wave: "0"

---
# Run smoke test last (wave 1)
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  annotations:
    argocd.argoproj.io/sync-wave: "1"     # positive = later
```

ArgoCD deploys in wave order and waits for each wave to become healthy before moving to the next.

### Pattern 5: Sync Hooks (Pre/Post Deploy Jobs)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync          # runs before sync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded  # delete job after success
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: myapp:latest
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
```

Hook types:
- `PreSync` — runs before deploying anything
- `Sync` — runs during sync
- `PostSync` — runs after all resources are healthy
- `SyncFail` — runs only if sync fails (for alerting/rollback)

---

## STEP 11 — Multi-Cluster Setup (Production Pattern)

In production, ArgoCD runs in a management cluster and deploys to multiple target clusters.

```bash
# Add a second cluster to ArgoCD
# First, make sure you have kubeconfig for the target cluster
kubectl config get-contexts

# Add the cluster (this creates a ServiceAccount + ClusterRole in target cluster)
argocd cluster add <context-name> --name production-cluster

# Verify
argocd cluster list
```

Output:
```
SERVER                          NAME                STATUS  MESSAGE
https://kubernetes.default.svc  in-cluster          OK
https://prod-eks.company.com    production-cluster  OK
```

Then in your Application, change the destination:

```yaml
destination:
  server: https://prod-eks.company.com    # target cluster
  namespace: nginx-prod
```

---

## STEP 12 — Useful Commands (Day-to-Day Operations)

```bash
# List all applications
argocd app list

# Get detailed app info (shows sync status, health, resources)
argocd app get nginx-app

# Manually trigger sync
argocd app sync nginx-app

# Sync and wait for completion
argocd app sync nginx-app --wait

# Rollback to a previous Git commit
argocd app rollback nginx-app <revision-number>
argocd app history nginx-app    # see revision numbers

# Hard refresh (bypasses cache, re-fetches from Git)
argocd app get nginx-app --hard-refresh

# Diff — show what would change before syncing
argocd app diff nginx-app

# Delete app (also deletes cluster resources because of finalizer)
argocd app delete nginx-app

# Force sync specific resources
argocd app sync nginx-app --resource apps:Deployment:nginx-deployment

# Pause auto-sync temporarily (useful during incident)
argocd app set nginx-app --sync-policy none

# Re-enable auto-sync
argocd app set nginx-app --sync-policy automated

# View live logs of a pod through ArgoCD
argocd app logs nginx-app

# Check RBAC permissions for current user
argocd account can-i sync applications nginx-app
```

---

## STEP 13 — Troubleshooting (Real Production Issues)

### Issue 1: App stuck in OutOfSync

```bash
argocd app get nginx-app
# Look at "SYNC STATUS" and "HEALTH STATUS"

# See detailed diff
argocd app diff nginx-app

# Check resource-level status
argocd app get nginx-app --show-operation
```

### Issue 2: Sync failing

```bash
# Check ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50

# Check repo server (if Git fetch is failing)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50

# Check if repo is accessible
argocd repo list
argocd repo get https://github.com/your-username/argocd-lab.git
```

### Issue 3: Unknown resources

```bash
# ArgoCD doesn't know about a CRD
# Fix: add the CRD to the project whitelist or use clusterResourceWhitelist
kubectl get crd | grep argocd

# Or check what resource group/kind to whitelist
kubectl api-resources | grep <resource-name>
```

### Issue 4: App healthy but not syncing

```bash
# Check if webhook is configured
argocd app get nginx-app -o json | jq .status.operationState

# Force refresh from Git
argocd app sync nginx-app --force

# Check Git revision
argocd app get nginx-app | grep "TARGET REVISION"
```

---

## Complete End-to-End Flow Summary

```
1. You write K8s YAML → commit → push to Git

2. ArgoCD detects change (via poll every 3min or webhook instantly)

3. ArgoCD checks AppProject:
   - Is this repo allowed?        → YES (sourceRepos)
   - Is this namespace allowed?   → YES (destinations)
   - Is this resource type OK?    → YES (whitelist)

4. ArgoCD applies changes via application-controller ServiceAccount
   → kubectl apply (internally)

5. Kubernetes deploys resources

6. ArgoCD continuously watches:
   - If cluster drifts from Git → selfHeal restores it
   - If you delete file from Git → prune removes from cluster
   - If image pull fails → retry with backoff

7. Status shown in UI: Synced / OutOfSync / Healthy / Degraded
```

---

## Resume-Ready Bullet Points

Use these in your 3 YOE resume under DevOps/GitOps:

- Implemented GitOps CD pipelines using ArgoCD on Kubernetes (EKS/KIND), enabling automated continuous deployment with Git as the single source of truth
- Configured ArgoCD AppProjects with namespace-level RBAC and resource whitelisting to enforce multi-team deployment isolation and prevent privilege escalation
- Set up automated sync with prune and selfHeal policies to enforce cluster state consistency and automatically remediate configuration drift
- Integrated ArgoCD with GitHub webhooks for sub-minute deployment propagation from Git push to cluster
- Implemented App of Apps pattern managing 20+ microservice deployments across dev/staging/prod environments using Kustomize overlays
- Configured sync waves and PreSync hooks for ordered deployment of dependent services including database migrations
- Set up multi-cluster ArgoCD managing deployments across dev, staging, and production EKS clusters from a central management cluster

---

## What to Practice Next

1. Add a second app (a simple Python/Node app) using this same repo
2. Practice Kustomize overlays — change replicas per environment
3. Add a PreSync hook (a dummy Job that runs before deploy)
4. Simulate a production incident: manually edit a deployment, watch selfHeal fix it
5. Add a Helm chart-based application
6. Set up App of Apps so all your apps are managed through Git


