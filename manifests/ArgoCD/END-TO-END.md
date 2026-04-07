Perfect. Here is a **full hands-on GitOps project** you can build and put on your resume as a **production-style Argo CD platform lab**.

I am going to give you a **realistic design**, not a toy example.

---

# Project goal

Build a GitOps-based Kubernetes platform that deploys and manages:

* frontend
* backend
* PostgreSQL
* shared RWX storage using NFS
* Kong Gateway
* KEDA autoscaling
* Cilium network policies
* namespace, RBAC, ConfigMaps, Secrets, PVCs
* Argo CD root app + child apps
* dev and prod environments

This gives you practice in:

* GitOps repo design
* platform bootstrap
* workload deployment
* environment separation
* ingress and traffic routing
* storage
* security
* autoscaling
* troubleshooting

---

# What you will build

## Application

A simple warehouse app:

* **frontend**: NGINX serving static UI
* **backend**: API service
* **database**: PostgreSQL
* **shared uploads**: NFS-backed PVC mounted into backend

---

# Real enterprise architecture

```text
Developer
   |
   v
App Source Repo
   |
   | CI builds image + pushes to registry
   v
Container Registry
   |
   | CI updates GitOps repo image tag
   v
GitOps Repo
   |
   v
Argo CD
   |
   v
Kubernetes Cluster
   |
   +--> Kong Gateway
   +--> frontend
   +--> backend
   +--> postgres
   +--> KEDA
   +--> NFS provisioner
   +--> Cilium policies
```

---

# What pods you will have

At the end, your cluster will have pods like:

## Platform pods

* argocd-server
* argocd-repo-server
* argocd-application-controller
* argocd-redis
* kong-controller
* kong-proxy
* keda-operator
* keda-metrics-apiserver
* nfs-subdir-external-provisioner
* metrics-server
* cilium-agent
* hubble-ui if enabled

## Workload pods

* frontend
* backend
* postgres

---

# Best repo design

Use **2 repos** in real style.

## 1. App source repo

Contains application code only.

```text
warehouse-app/
  frontend/
  backend/
  Dockerfile.frontend
  Dockerfile.backend
  .github/workflows/ci.yaml
```

## 2. GitOps repo

Contains deployment state only.

```text
warehouse-gitops/
  bootstrap/
    root-app.yaml

  projects/
    warehouse-project.yaml

  platform/
    kong/
      app.yaml
      values.yaml
    keda/
      app.yaml
      values.yaml
    nfs/
      app.yaml
      values.yaml
    metrics-server/
      app.yaml

  apps/
    warehouse/
      base/
        namespace.yaml
        serviceaccount.yaml
        role.yaml
        rolebinding.yaml
        configmap.yaml
        secret.yaml
        postgres-service.yaml
        postgres-statefulset.yaml
        backend-service.yaml
        backend-deployment.yaml
        frontend-service.yaml
        frontend-deployment.yaml
        pvc-uploads.yaml
        networkpolicy-default-deny.yaml
        networkpolicy-allow-dns.yaml
        networkpolicy-kong-to-frontend.yaml
        networkpolicy-kong-to-backend.yaml
        networkpolicy-backend-to-postgres.yaml
        keda-scaledobject-backend.yaml
        kong-gateway.yaml
        httproute-frontend.yaml
        httproute-backend.yaml
        kustomization.yaml

      overlays/
        dev/
          kustomization.yaml
          patches.yaml
          app.yaml
        prod/
          kustomization.yaml
          patches.yaml
          app.yaml
```

---

# Why this structure is enterprise-level

Because it separates:

* **platform components** from **business app**
* **base manifests** from **environment overlays**
* **source code** from **deployment state**
* **cluster bootstrap** from **app deployment**

This is exactly the kind of thing interviewers like.

---

# Phase-by-phase implementation

---

## Phase 1: Cluster prerequisites

You need a Kubernetes cluster with:

* Argo CD
* Cilium
* metrics-server
* StorageClass for PostgreSQL
* NFS provisioner for shared RWX storage
* Kong
* KEDA

For local practice you can use:

* KIND
* MetalLB
* Cilium
* Kong
* Argo CD

For cloud practice you can use:

* EKS
* EFS for RWX
* EBS for PostgreSQL
* ALB/NLB or Kong

For your learning, this lab works great on **KIND + MetalLB + Cilium**.

---

## Phase 2: Bootstrap Argo CD

Install Argo CD first.

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd
```

Expose Argo CD server for access in your lab if needed.

---

# Root app pattern

In enterprise, we usually do not manually create every app from UI.

We bootstrap with one **root app**.

## `bootstrap/root-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/warehouse-gitops.git
    targetRevision: main
    path: bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Then in `bootstrap/` you can reference project files and child apps.

---

# AppProject

Use AppProject so this looks real.

## `projects/warehouse-project.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: warehouse
  namespace: argocd
spec:
  description: Warehouse platform project
  sourceRepos:
    - https://github.com/your-org/warehouse-gitops.git
    - https://charts.konghq.com
    - https://kedacore.github.io/charts
    - https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
  destinations:
    - namespace: warehouse-dev
      server: https://kubernetes.default.svc
    - namespace: warehouse-prod
      server: https://kubernetes.default.svc
    - namespace: kong
      server: https://kubernetes.default.svc
    - namespace: keda
      server: https://kubernetes.default.svc
    - namespace: nfs-provisioner
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

---

# Phase 3: Platform components managed by Argo CD

This is very enterprise-like.

Instead of installing everything manually, Argo CD manages platform apps too.

---

## Kong as Argo CD app

## `platform/kong/app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kong
  namespace: argocd
spec:
  project: warehouse
  source:
    repoURL: https://charts.konghq.com
    chart: kong
    targetRevision: "<pin-a-tested-version>"
    helm:
      valueFiles:
        - $values/platform/kong/values.yaml
  sources:
    - repoURL: https://charts.konghq.com
      chart: kong
      targetRevision: "<pin-a-tested-version>"
      helm:
        valueFiles:
          - $values/platform/kong/values.yaml
    - repoURL: https://github.com/your-org/warehouse-gitops.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: kong
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## `platform/kong/values.yaml`

```yaml
deployment:
  kong:
    enabled: true

ingressController:
  enabled: true

env:
  database: "off"

proxy:
  type: LoadBalancer

admin:
  enabled: false
```

---

## KEDA as Argo CD app

## `platform/keda/app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keda
  namespace: argocd
spec:
  project: warehouse
  source:
    repoURL: https://kedacore.github.io/charts
    chart: keda
    targetRevision: "<pin-a-tested-version>"
  destination:
    server: https://kubernetes.default.svc
    namespace: keda
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## NFS provisioner as Argo CD app

In real enterprise, RWX would usually be:

* EFS on AWS
* Azure Files
* NetApp
* corporate NFS

For lab, use NFS provisioner.

## `platform/nfs/app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nfs-provisioner
  namespace: argocd
spec:
  project: warehouse
  source:
    repoURL: https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
    chart: nfs-subdir-external-provisioner
    targetRevision: "<pin-a-tested-version>"
    helm:
      valueFiles:
        - $values/platform/nfs/values.yaml
  sources:
    - repoURL: https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
      chart: nfs-subdir-external-provisioner
      targetRevision: "<pin-a-tested-version>"
      helm:
        valueFiles:
          - $values/platform/nfs/values.yaml
    - repoURL: https://github.com/your-org/warehouse-gitops.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: nfs-provisioner
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## `platform/nfs/values.yaml`

```yaml
storageClass:
  create: true
  name: nfs-client
  defaultClass: false

nfs:
  server: 10.0.0.50
  path: /srv/nfs/k8s
```

For local lab, point this to your reachable NFS server.

---

# Phase 4: Business application manifests

Now create the actual workload.

---

## Namespace

## `apps/warehouse/base/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: warehouse-dev
  labels:
    app.kubernetes.io/name: warehouse
```

For prod you use overlay namespace change.

---

## Service account

## `serviceaccount.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: warehouse-backend
  namespace: warehouse-dev
```

---

## Role

## `role.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: warehouse-config-reader
  namespace: warehouse-dev
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
```

---

## RoleBinding

## `rolebinding.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: warehouse-config-reader-binding
  namespace: warehouse-dev
subjects:
  - kind: ServiceAccount
    name: warehouse-backend
    namespace: warehouse-dev
roleRef:
  kind: Role
  name: warehouse-config-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## ConfigMap

## `configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: warehouse-config
  namespace: warehouse-dev
data:
  APP_ENV: dev
  DB_HOST: postgres
  DB_PORT: "5432"
  DB_NAME: warehouse
  UPLOAD_PATH: /app/uploads
```

---

## Secret

For lab only you can use this.
In real enterprise, replace with ExternalSecret / Vault / SealedSecret.

## `secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: warehouse-secret
  namespace: warehouse-dev
type: Opaque
stringData:
  DB_USER: warehouse
  DB_PASSWORD: warehouse123
```

---

# PostgreSQL with PVC

Use a StatefulSet because DB needs stable identity and persistent storage.

## `postgres-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: warehouse-dev
spec:
  selector:
    app: postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
```

## `postgres-statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: warehouse-dev
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              valueFrom:
                configMapKeyRef:
                  name: warehouse-config
                  key: DB_NAME
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: warehouse-secret
                  key: DB_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: warehouse-secret
                  key: DB_PASSWORD
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
          readinessProbe:
            exec:
              command: ["sh", "-c", "pg_isready -U $POSTGRES_USER"]
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            tcpSocket:
              port: 5432
            initialDelaySeconds: 20
            periodSeconds: 10
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "500m"
              memory: "1Gi"
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 10Gi
```

In cloud, this would typically use EBS-backed StorageClass.

---

# NFS PVC for shared uploads

## `pvc-uploads.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: warehouse-uploads
  namespace: warehouse-dev
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Gi
```

This is for files uploaded by backend and shared across replicas.

---

# Backend deployment

## `backend-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: warehouse-dev
spec:
  selector:
    app: backend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

## `backend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: warehouse-dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      serviceAccountName: warehouse-backend
      containers:
        - name: backend
          image: ghcr.io/your-org/warehouse-backend:1.0.0
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: warehouse-config
            - secretRef:
                name: warehouse-secret
          volumeMounts:
            - name: uploads
              mountPath: /app/uploads
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 20
            periodSeconds: 10
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
      volumes:
        - name: uploads
          persistentVolumeClaim:
            claimName: warehouse-uploads
```

---

# Frontend deployment

## `frontend-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: warehouse-dev
spec:
  selector:
    app: frontend
  ports:
    - name: http
      port: 80
      targetPort: 80
```

## `frontend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: warehouse-dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: ghcr.io/your-org/warehouse-frontend:1.0.0
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
```

---

# KEDA autoscaling

You wanted KEDA, so use it for backend.

## `keda-scaledobject-backend.yaml`

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: backend-scaledobject
  namespace: warehouse-dev
spec:
  scaleTargetRef:
    name: backend
  pollingInterval: 15
  cooldownPeriod: 60
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"
    - type: memory
      metricType: Utilization
      metadata:
        value: "75"
```

This gives you KEDA practice without needing Kafka/SQS first.

Later you can extend it to:

* RabbitMQ
* Kafka
* SQS
* Prometheus custom metrics

---

# Kong Gateway routing

Since you have been learning Gateway API, use that.

## `kong-gateway.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: warehouse-gateway
  namespace: warehouse-dev
spec:
  gatewayClassName: kong
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: warehouse.local
```

## `httproute-frontend.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: warehouse-frontend
  namespace: warehouse-dev
spec:
  parentRefs:
    - name: warehouse-gateway
  hostnames:
    - warehouse.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: frontend
          port: 80
```

## `httproute-backend.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: warehouse-backend
  namespace: warehouse-dev
spec:
  parentRefs:
    - name: warehouse-gateway
  hostnames:
    - api.warehouse.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: backend
          port: 8080
```

---

# Cilium network policies

You asked for production-level practice, so do not leave traffic fully open.

---

## Default deny

## `networkpolicy-default-deny.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
  namespace: warehouse-dev
spec:
  endpointSelector: {}
  ingress: []
  egress: []
```

---

## Allow DNS

## `networkpolicy-allow-dns.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns
  namespace: warehouse-dev
spec:
  endpointSelector: {}
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s:k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
          rules:
            dns:
              - matchPattern: "*"
```

---

## Allow Kong to frontend

## `networkpolicy-kong-to-frontend.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-kong-to-frontend
  namespace: warehouse-dev
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kong
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

---

## Allow Kong to backend

## `networkpolicy-kong-to-backend.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-kong-to-backend
  namespace: warehouse-dev
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kong
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

---

## Allow backend to postgres

## `networkpolicy-backend-to-postgres.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-backend-to-postgres
  namespace: warehouse-dev
spec:
  endpointSelector:
    matchLabels:
      app: postgres
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
```

You can later add:

* backend egress to postgres
* backend egress to specific external APIs
* deny all internet except allowed domains

---

# Kustomize base

## `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - serviceaccount.yaml
  - role.yaml
  - rolebinding.yaml
  - configmap.yaml
  - secret.yaml
  - postgres-service.yaml
  - postgres-statefulset.yaml
  - pvc-uploads.yaml
  - backend-service.yaml
  - backend-deployment.yaml
  - frontend-service.yaml
  - frontend-deployment.yaml
  - keda-scaledobject-backend.yaml
  - kong-gateway.yaml
  - httproute-frontend.yaml
  - httproute-backend.yaml
  - networkpolicy-default-deny.yaml
  - networkpolicy-allow-dns.yaml
  - networkpolicy-kong-to-frontend.yaml
  - networkpolicy-kong-to-backend.yaml
  - networkpolicy-backend-to-postgres.yaml
```

---

# Dev overlay

## `apps/warehouse/overlays/dev/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: warehouse-dev
resources:
  - ../../base
patchesStrategicMerge:
  - patches.yaml
images:
  - name: ghcr.io/your-org/warehouse-backend
    newTag: dev-1
  - name: ghcr.io/your-org/warehouse-frontend
    newTag: dev-1
```

## `patches.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
```

---

# Argo CD app for dev

## `apps/warehouse/overlays/dev/app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: warehouse-dev
  namespace: argocd
spec:
  project: warehouse
  source:
    repoURL: https://github.com/your-org/warehouse-gitops.git
    targetRevision: main
    path: apps/warehouse/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: warehouse-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Create similar one for prod.

---

# CI pipeline design

Now the enterprise GitOps part.

Your CI pipeline should not directly deploy to cluster.

It should:

1. build image
2. scan image/code
3. push image to registry
4. update GitOps repo tag
5. Argo CD deploys automatically

---

## Example CI flow

```text
Commit to app repo
   ->
CI runs tests
   ->
Docker image build
   ->
Push to registry
   ->
Update image tag in GitOps repo
   ->
Create PR or direct commit
   ->
Merge
   ->
Argo CD sync
```

---

## Example GitHub Actions idea

In app repo:

```yaml
name: Build and Publish

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build backend image
        run: docker build -t ghcr.io/your-org/warehouse-backend:${{ github.sha }} -f Dockerfile.backend .

      - name: Push backend image
        run: echo "push to registry here"

      - name: Update GitOps repo image tag
        run: |
          git clone https://github.com/your-org/warehouse-gitops.git
          cd warehouse-gitops/apps/warehouse/overlays/dev
          sed -i 's/newTag:.*/newTag: '"${GITHUB_SHA}"'/' kustomization.yaml
          git config user.name "ci-bot"
          git config user.email "ci-bot@example.com"
          git commit -am "Update backend image tag to ${GITHUB_SHA}"
          git push
```

In real projects, this step is often done through:

* PR automation
* Argo CD Image Updater
* Jenkins scripted pipelines
* GitHub App bot

---

# End-to-end traffic flow

```text
User
  |
  v
Kong LoadBalancer / MetalLB external IP
  |
  v
Gateway listener
  |
  v
HTTPRoute
  |
  +--> frontend service --> frontend pods
  |
  +--> backend service --> backend pods
                           |
                           +--> postgres service --> postgres pod
                           |
                           +--> NFS RWX PVC for uploads
```

---

# Day-2 operations you should practice

This is where the real learning happens.

## 1. App becomes OutOfSync

Practice:

* manually edit deployment in cluster
* watch Argo CD mark it OutOfSync
* let self-heal revert it

## 2. Image upgrade

Practice:

* change image tag in Git
* sync and verify rollout

## 3. Broken readiness probe

Practice:

* make wrong readiness path
* see app Degraded
* debug with `kubectl describe`

## 4. Network policy block

Practice:

* remove backend-to-postgres policy
* confirm backend cannot connect DB

## 5. Storage issue

Practice:

* wrong StorageClass
* PVC pending
* inspect events

## 6. Kong route issue

Practice:

* wrong hostname or route
* verify with `kubectl get httproute`

## 7. KEDA scaling

Practice:

* stress backend
* watch replicas scale

## 8. Rollback

Practice:

* revert Git commit
* confirm Argo CD rolls back

---

# Useful debug commands

```bash
kubectl get applications -n argocd
kubectl describe application warehouse-dev -n argocd

kubectl get pods -A
kubectl get svc -A
kubectl get pvc -A
kubectl get httproute -A
kubectl get gateway -A

kubectl describe pod <pod-name> -n warehouse-dev
kubectl logs deploy/backend -n warehouse-dev
kubectl logs deploy/frontend -n warehouse-dev
kubectl logs statefulset/postgres -n warehouse-dev

kubectl get scaledobject -n warehouse-dev
kubectl describe scaledobject backend-scaledobject -n warehouse-dev

kubectl get ciliumnetworkpolicy -n warehouse-dev
kubectl describe ciliumnetworkpolicy allow-backend-to-postgres -n warehouse-dev

kubectl get endpoints -n warehouse-dev
kubectl top pods -n warehouse-dev
kubectl top nodes
```

If using Argo CD CLI:

```bash
argocd app list
argocd app get warehouse-dev
argocd app sync warehouse-dev
argocd app diff warehouse-dev
```

---

# How to make this even more enterprise-level later

After completing this version, extend it with:

* External Secrets Operator
* Argo Rollouts for blue-green or canary
* ApplicationSet for multi-cluster deployments
* separate dev and prod clusters
* image scanning with Trivy
* policy enforcement with Kyverno or OPA Gatekeeper
* PostgreSQL backup CronJob
* PodDisruptionBudget
* anti-affinity
* HPA vs KEDA comparison
* cert-manager + HTTPS
* SSO for Argo CD

---

# Resume-quality project summary

You can describe this as:

Built a production-style GitOps delivery platform on Kubernetes using Argo CD to manage platform components and application workloads across environments. Implemented Kustomize-based environment overlays, Kong Gateway API routing, PostgreSQL StatefulSet with persistent storage, NFS-backed RWX shared volumes, KEDA autoscaling, RBAC, ConfigMaps, Secrets, and Cilium network policies. Established Git-driven deployments with image promotion through a separate GitOps repository and practiced day-2 operations including drift correction, rollback, traffic debugging, storage troubleshooting, and autoscaling validation.

---

# Best implementation order

Do it in this exact order:

1. cluster + Cilium + MetalLB
2. Argo CD install
3. root app bootstrap
4. Kong app
5. metrics-server app
6. KEDA app
7. NFS provisioner app
8. warehouse base manifests
9. dev overlay app
10. test routing
11. test DB
12. test uploads PVC
13. apply network policies
14. test autoscaling
15. automate image update flow from CI

---

# My honest recommendation

Do not start with everything at once.

Implement in 3 milestones:

## Milestone 1

* Argo CD
* frontend
* backend
* postgres
* Kong

## Milestone 2

* PVC
* NFS RWX
* KEDA
* ConfigMap
* Secret
* RBAC

## Milestone 3

* Cilium policies
* CI image update
* rollback drills
* prod overlay
* app-of-apps cleanup

That will make it much easier to complete properly.

If you want, next I’ll turn this into a **complete GitHub-ready `.md` file with all manifests in one structured document**.
