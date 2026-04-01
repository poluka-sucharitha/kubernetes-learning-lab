````md
# Istio + Cilium + MetalLB End-to-End Practice Lab on kind

This lab is designed so you can practice **real-world Kubernetes traffic control end to end** with:

- **kind** cluster
- **Cilium** for Kubernetes networking and network policies
- **Istio** for service mesh, mTLS, blue-green routing
- **MetalLB** for `LoadBalancer` support in kind
- **RBAC** with `ServiceAccount`, `Role`, `RoleBinding`
- **PV / PVC**
- **ConfigMap**
- **Readiness / Liveness probes**
- **HPA**
- **Ingress from external client**
- **Pod-to-pod allow / deny**
- **Egress restriction to only Google**
- **Edge-case testing**

---

# 1. What you will practice

At the end of this lab, your flow will look like this:

```text
Client
  ↓
MetalLB External IP
  ↓
Istio Ingress Gateway
  ↓
VirtualService
  ↓
frontend Service
  ↓
frontend Pods (blue / green versions)
  ↓
backend Service
  ↓
backend Pods
````

And at the same time:

* **Istio** will handle:

  * ingress routing
  * blue-green traffic shifting
  * mTLS between mesh workloads

* **Cilium** will handle:

  * pod-to-pod allow / deny
  * ingress/egress restrictions
  * FQDN-based egress to only `www.google.com`

* **Kubernetes** will handle:

  * ServiceAccount / Role / RoleBinding
  * ConfigMap
  * PV / PVC
  * probes
  * HPA

---

# 2. High-level architecture

Namespaces used:

* `istio-system` → Istio control plane + ingress gateway
* `metallb-system` → MetalLB controller and speakers
* `mesh-lab` → your application namespace
* `kube-system` → DNS, metrics-server, etc.

Apps in `mesh-lab`:

* `frontend` → exposed via Istio ingress
* `backend` → only reachable from frontend
* `toolbox` → used for curl / DNS / Google egress tests

---

# 3. End-to-end learning goals

You wanted these scenarios. This lab includes all of them:

1. **Allow pod-to-pod traffic**
2. **Deny pod-to-pod traffic**
3. **Restrict ingress**
4. **Restrict egress**
5. **Allow only Google externally**
6. **Enable strict Istio mTLS**
7. **Blue-green deployment**
8. **Use ServiceAccount, Role, RoleBinding**
9. **Use PV and PVC**
10. **Use readinessProbe and livenessProbe**
11. **Use HPA**
12. **Use ConfigMap**
13. **Expose app externally in kind using MetalLB**
14. **Practice edge cases and failures**

---

# 4. Prerequisites

Install these on your machine / VM:

* Docker
* kubectl
* kind
* helm
* cilium CLI
* istioctl

Check:

```bash
docker version
kubectl version --client
kind version
helm version
cilium version
istioctl version
```

---

# 5. Create kind cluster for Cilium

## 5.1 kind cluster config

Create `00-kind-cluster.yaml`

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-cilium-lab
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

Create cluster:

```bash
kind create cluster --config 00-kind-cluster.yaml
kubectl cluster-info --context kind-istio-cilium-lab
kubectl get nodes
```

---

# 6. Install Cilium

Install Cilium as the CNI:

```bash
cilium install --set ipam.mode=kubernetes
cilium status --wait
kubectl get pods -n kube-system
```

Optional but useful:

```bash
cilium hubble enable --ui
cilium status
```

If you enabled Hubble UI:

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

---

# 7. Install MetalLB

Install MetalLB:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
kubectl get pods -n metallb-system
```

## 7.1 Configure IP pool

Create `01-metallb-pool.yaml`

> Adjust the IP range if your kind docker network is different.
> In many kind setups it is something like `172.18.255.200-172.18.255.250`.

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
    - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - kind-pool
```

Apply:

```bash
kubectl apply -f 01-metallb-pool.yaml
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

---

# 8. Install Istio

Install Istio:

```bash
istioctl install -y
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

You should see `istio-ingressgateway` service. Since MetalLB is installed, it should receive an external IP.

Check:

```bash
kubectl get svc istio-ingressgateway -n istio-system
```

---

# 9. Install metrics-server for HPA

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get pods -n kube-system | grep metrics-server
kubectl top nodes
```

If `kubectl top` does not work immediately, wait a bit.

---

# 10. Create application namespace with Istio injection

Create `02-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mesh-lab
  labels:
    istio-injection: enabled
```

Apply:

```bash
kubectl apply -f 02-namespace.yaml
kubectl get ns --show-labels
```

---

# 11. Create ConfigMap

Create `03-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: mesh-lab
data:
  FRONTEND_MESSAGE: "Hello from frontend using ConfigMap"
  BACKEND_MESSAGE: "Hello from backend using ConfigMap"
```

Apply:

```bash
kubectl apply -f 03-configmap.yaml
kubectl get cm -n mesh-lab
```

---

# 12. Create ServiceAccount, Role, RoleBinding

This is for practicing RBAC.

Create `04-rbac.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: mesh-lab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader-role
  namespace: mesh-lab
rules:
  - apiGroups: [""]
    resources: ["configmaps", "pods"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: mesh-lab
subjects:
  - kind: ServiceAccount
    name: app-reader
    namespace: mesh-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-reader-role
```

Apply:

```bash
kubectl apply -f 04-rbac.yaml
```

Test:

```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:mesh-lab:app-reader -n mesh-lab
kubectl auth can-i get secrets --as=system:serviceaccount:mesh-lab:app-reader -n mesh-lab
```

Expected:

* configmaps → **yes**
* secrets → **no**

---

# 13. Create PV and PVC

For kind practice, use a static `hostPath` PV.

Create `05-pv-pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mesh-lab-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/mesh-lab-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mesh-lab-pvc
  namespace: mesh-lab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 1Gi
```

Apply:

```bash
kubectl apply -f 05-pv-pvc.yaml
kubectl get pv
kubectl get pvc -n mesh-lab
```

---

# 14. Backend deployment and service

Backend should be reachable only from frontend.

Create `06-backend.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: mesh-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: app-reader
      containers:
        - name: backend
          image: hashicorp/http-echo:1.0.0
          args:
            - "-text=backend-v1"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
          env:
            - name: BACKEND_MESSAGE
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: BACKEND_MESSAGE
          readinessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          volumeMounts:
            - name: app-storage
              mountPath: /data
      volumes:
        - name: app-storage
          persistentVolumeClaim:
            claimName: mesh-lab-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: mesh-lab
spec:
  selector:
    app: backend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

Apply:

```bash
kubectl apply -f 06-backend.yaml
kubectl get pods -n mesh-lab -o wide
kubectl get svc -n mesh-lab
```

---

# 15. Frontend blue and green deployments

We will create two versions:

* `frontend-blue`
* `frontend-green`

Both belong to the same service `frontend`.

Create `07-frontend-blue-green.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-blue
  namespace: mesh-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      version: blue
  template:
    metadata:
      labels:
        app: frontend
        version: blue
    spec:
      serviceAccountName: app-reader
      containers:
        - name: frontend
          image: hashicorp/http-echo:1.0.0
          args:
            - "-text=frontend-blue"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
          env:
            - name: FRONTEND_MESSAGE
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: FRONTEND_MESSAGE
          readinessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-green
  namespace: mesh-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      version: green
  template:
    metadata:
      labels:
        app: frontend
        version: green
    spec:
      serviceAccountName: app-reader
      containers:
        - name: frontend
          image: hashicorp/http-echo:1.0.0
          args:
            - "-text=frontend-green"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: mesh-lab
spec:
  selector:
    app: frontend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

Apply:

```bash
kubectl apply -f 07-frontend-blue-green.yaml
kubectl get pods -n mesh-lab --show-labels
kubectl get svc -n mesh-lab
```

---

# 16. Toolbox pod for testing

This pod is used for:

* curl
* nslookup
* Google egress test
* internal connectivity test

Create `08-toolbox.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: toolbox
  namespace: mesh-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: toolbox
  template:
    metadata:
      labels:
        app: toolbox
    spec:
      serviceAccountName: app-reader
      containers:
        - name: toolbox
          image: curlimages/curl:8.7.1
          command: ["/bin/sh", "-c"]
          args:
            - "sleep 36000"
```

Apply:

```bash
kubectl apply -f 08-toolbox.yaml
kubectl get pods -n mesh-lab
```

---

# 17. Istio strict mTLS

This enables strict mTLS for all workloads in `mesh-lab`.

Create `09-istio-mtls.yaml`

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mesh-lab
spec:
  mtls:
    mode: STRICT
```

Apply:

```bash
kubectl apply -f 09-istio-mtls.yaml
```

## What this means

* Pod-to-pod traffic **inside the mesh** must use Istio mTLS
* Traffic between injected sidecars is encrypted and identity-aware
* If a pod has **no sidecar**, it may fail to talk to strict mesh workloads

---

# 18. Istio DestinationRule for blue-green subsets

This defines subsets for `frontend` service.

Create `10-destinationrule.yaml`

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: frontend-dr
  namespace: mesh-lab
spec:
  host: frontend.mesh-lab.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
  subsets:
    - name: blue
      labels:
        version: blue
    - name: green
      labels:
        version: green
```

Apply:

```bash
kubectl apply -f 10-destinationrule.yaml
```

---

# 19. Istio Gateway and VirtualService

Expose frontend externally through Istio ingress gateway.

Create `11-gateway-virtualservice.yaml`

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: mesh-lab-gateway
  namespace: mesh-lab
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "frontend.local"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: mesh-lab
spec:
  hosts:
    - "frontend.local"
  gateways:
    - mesh-lab-gateway
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: frontend.mesh-lab.svc.cluster.local
            subset: blue
            port:
              number: 8080
          weight: 100
        - destination:
            host: frontend.mesh-lab.svc.cluster.local
            subset: green
            port:
              number: 8080
          weight: 0
```

Apply:

```bash
kubectl apply -f 11-gateway-virtualservice.yaml
```

Check ingress external IP:

```bash
kubectl get svc istio-ingressgateway -n istio-system
```

Test:

```bash
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: frontend.local" http://$INGRESS_IP/
```

Expected initially:

```text
frontend-blue
```

---

# 20. Optional Istio ServiceEntry for Google

If you want external Google access to be explicitly registered in Istio as well, create this.

Create `12-google-serviceentry.yaml`

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: google-external
  namespace: mesh-lab
spec:
  hosts:
    - www.google.com
  location: MESH_EXTERNAL
  ports:
    - number: 443
      name: https
      protocol: TLS
  resolution: DNS
```

Apply:

```bash
kubectl apply -f 12-google-serviceentry.yaml
```

> This is especially useful if later you want to tighten Istio outbound policy further.

---

# 21. Cilium network policies

Now the most important practice part.

We will build policies gradually.

---

## 21.1 Allow DNS first

Without DNS, FQDN rules and service resolution will fail.

Create `13-cnp-allow-dns.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns
  namespace: mesh-lab
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

Apply:

```bash
kubectl apply -f 13-cnp-allow-dns.yaml
```

---

## 21.2 Default deny all ingress and egress in app namespace

Create `14-cnp-default-deny.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
  namespace: mesh-lab
spec:
  endpointSelector: {}
  ingress: []
  egress: []
```

Apply:

```bash
kubectl apply -f 14-cnp-default-deny.yaml
```

Now traffic in `mesh-lab` is denied unless allowed by other policies.

---

## 21.3 Allow Istio ingress gateway to frontend

Create `15-cnp-allow-ingressgateway-to-frontend.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-istio-ingress-to-frontend
  namespace: mesh-lab
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: istio-system
            istio: ingressgateway
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

Apply:

```bash
kubectl apply -f 15-cnp-allow-ingressgateway-to-frontend.yaml
```

---

## 21.4 Allow frontend to backend only on 8080

Create `16-cnp-allow-frontend-to-backend.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: mesh-lab
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

Apply:

```bash
kubectl apply -f 16-cnp-allow-frontend-to-backend.yaml
```

Now only frontend pods can reach backend on port `8080`.

---

## 21.5 Allow toolbox to Google only

This is for your external egress practice.

Create `17-cnp-toolbox-google-egress.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: toolbox-google-egress
  namespace: mesh-lab
spec:
  endpointSelector:
    matchLabels:
      app: toolbox
  egress:
    - toFQDNs:
        - matchName: www.google.com
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

Apply:

```bash
kubectl apply -f 17-cnp-toolbox-google-egress.yaml
```

---

## 21.6 Allow toolbox to frontend and backend for internal testing

Create `18-cnp-toolbox-to-apps.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: toolbox-to-apps
  namespace: mesh-lab
spec:
  endpointSelector:
    matchLabels:
      app: toolbox
  egress:
    - toEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

Apply:

```bash
kubectl apply -f 18-cnp-toolbox-to-apps.yaml
```

---

# 22. HPA

Create HPA for frontend deployment.

Create `19-hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-blue-hpa
  namespace: mesh-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend-blue
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Apply:

```bash
kubectl apply -f 19-hpa.yaml
kubectl get hpa -n mesh-lab
```

> To make HPA work properly, add CPU requests/limits to the deployment later if needed.

Example CPU section you can add to `frontend-blue` container:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "64Mi"
  limits:
    cpu: "300m"
    memory: "128Mi"
```

---

# 23. Load generator for HPA test

Create `20-load-generator.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loadgen
  namespace: mesh-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loadgen
  template:
    metadata:
      labels:
        app: loadgen
    spec:
      containers:
        - name: loadgen
          image: busybox
          command: ["/bin/sh", "-c"]
          args:
            - "while true; do wget -q -O- http://frontend:8080/; done"
```

Apply only when needed:

```bash
kubectl apply -f 20-load-generator.yaml
kubectl get hpa -n mesh-lab -w
```

Delete when done:

```bash
kubectl delete -f 20-load-generator.yaml
```

---

# 24. Recommended apply order

Apply in this order:

```bash
kubectl apply -f 02-namespace.yaml
kubectl apply -f 03-configmap.yaml
kubectl apply -f 04-rbac.yaml
kubectl apply -f 05-pv-pvc.yaml
kubectl apply -f 06-backend.yaml
kubectl apply -f 07-frontend-blue-green.yaml
kubectl apply -f 08-toolbox.yaml
kubectl apply -f 09-istio-mtls.yaml
kubectl apply -f 10-destinationrule.yaml
kubectl apply -f 11-gateway-virtualservice.yaml
kubectl apply -f 12-google-serviceentry.yaml
kubectl apply -f 13-cnp-allow-dns.yaml
kubectl apply -f 14-cnp-default-deny.yaml
kubectl apply -f 15-cnp-allow-ingressgateway-to-frontend.yaml
kubectl apply -f 16-cnp-allow-frontend-to-backend.yaml
kubectl apply -f 17-cnp-toolbox-google-egress.yaml
kubectl apply -f 18-cnp-toolbox-to-apps.yaml
kubectl apply -f 19-hpa.yaml
```

---

# 25. Validation commands

## 25.1 Basic status

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get cnp -n mesh-lab
kubectl get peerauthentication,destinationrule,virtualservice,gateway -n mesh-lab
kubectl get pv,pvc -A
kubectl get hpa -n mesh-lab
```

## 25.2 Check sidecars injected

```bash
kubectl get pods -n mesh-lab
kubectl get pod -n mesh-lab <pod-name> -o jsonpath='{.spec.containers[*].name}'
```

You should see app container + `istio-proxy`.

---

# 26. Test scenarios

---

## Scenario 1: External traffic through Istio ingress

```bash
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: frontend.local" http://$INGRESS_IP/
```

Expected:

```text
frontend-blue
```

---

## Scenario 2: Blue-green switch

Update `VirtualService` weights:

### Switch to green 100%

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: mesh-lab
spec:
  hosts:
    - "frontend.local"
  gateways:
    - mesh-lab-gateway
  http:
    - route:
        - destination:
            host: frontend.mesh-lab.svc.cluster.local
            subset: blue
            port:
              number: 8080
          weight: 0
        - destination:
            host: frontend.mesh-lab.svc.cluster.local
            subset: green
            port:
              number: 8080
          weight: 100
```

Apply and test again:

```bash
kubectl apply -f 11-gateway-virtualservice.yaml
curl -H "Host: frontend.local" http://$INGRESS_IP/
```

Expected:

```text
frontend-green
```

### Canary style

* blue = 80
* green = 20

Then call multiple times:

```bash
for i in $(seq 1 20); do curl -s -H "Host: frontend.local" http://$INGRESS_IP/; echo; done
```

---

## Scenario 3: Toolbox can reach frontend and backend

```bash
TOOLBOX=$(kubectl get pod -n mesh-lab -l app=toolbox -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mesh-lab $TOOLBOX -c toolbox -- curl -s http://frontend:8080/
kubectl exec -n mesh-lab $TOOLBOX -c toolbox -- curl -s http://backend:8080/
```

Expected:

* frontend responds
* backend responds

---

## Scenario 4: Pod-to-pod deny case

Delete allow policy from frontend to backend:

```bash
kubectl delete -f 16-cnp-allow-frontend-to-backend.yaml
```

Now test from a frontend pod to backend.

Find a frontend pod:

```bash
kubectl get pods -n mesh-lab -l app=frontend
```

Try from toolbox to backend still may work if toolbox policy exists.
But frontend → backend should fail once not allowed.

Reapply afterward:

```bash
kubectl apply -f 16-cnp-allow-frontend-to-backend.yaml
```

---

## Scenario 5: Strict mTLS

Because `PeerAuthentication` is `STRICT`, communication between mesh workloads must use sidecars.

Create a non-injected pod in another namespace and try to talk to frontend or backend.

Create `21-no-sidecar-test.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: no-mesh
---
apiVersion: v1
kind: Pod
metadata:
  name: nomesh-curl
  namespace: no-mesh
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.7.1
      command: ["/bin/sh", "-c"]
      args:
        - "sleep 36000"
```

Apply:

```bash
kubectl apply -f 21-no-sidecar-test.yaml
kubectl exec -n no-mesh nomesh-curl -- curl -v http://frontend.mesh-lab.svc.cluster.local:8080/
```

Expected:

* likely fail because strict mesh expects mTLS
* this is an important edge-case practice

---

## Scenario 6: Google-only external access

From toolbox:

```bash
kubectl exec -n mesh-lab $TOOLBOX -c toolbox -- nslookup www.google.com
kubectl exec -n mesh-lab $TOOLBOX -c toolbox -- curl -I https://www.google.com
```

Expected:

* DNS works
* Google works

Now try another site:

```bash
kubectl exec -n mesh-lab $TOOLBOX -c toolbox -- curl -I https://example.com --max-time 10
```

Expected:

* fail / timeout / blocked

This proves only Google external egress is allowed.

---

## Scenario 7: Remove DNS allow policy

Delete DNS policy:

```bash
kubectl delete -f 13-cnp-allow-dns.yaml
```

Now try:

```bash
kubectl exec -n mesh-lab $TOOLBOX -c toolbox -- nslookup www.google.com
```

Expected:

* DNS fails

Reapply:

```bash
kubectl apply -f 13-cnp-allow-dns.yaml
```

This is one of the most important Cilium edge cases.

---

## Scenario 8: Probe behavior

Check pod status:

```bash
kubectl describe pod -n mesh-lab <frontend-pod-name>
```

Look at:

* `Readiness`
* `Liveness`
* restart count
* events

To simulate failure, patch container args to use wrong port or wrong listen address.
Then observe:

* readiness becomes false
* pod removed from service endpoints
* liveness may restart the container

Check endpoints:

```bash
kubectl get endpoints -n mesh-lab frontend
```

Only ready pods appear.

---

## Scenario 9: RBAC verification

```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:mesh-lab:app-reader -n mesh-lab
kubectl auth can-i list pods --as=system:serviceaccount:mesh-lab:app-reader -n mesh-lab
kubectl auth can-i get secrets --as=system:serviceaccount:mesh-lab:app-reader -n mesh-lab
```

Expected:

* configmaps → yes
* pods → yes
* secrets → no

---

## Scenario 10: PVC mounted into backend

Check volume mount:

```bash
kubectl describe pod -n mesh-lab -l app=backend
kubectl get pvc -n mesh-lab
kubectl get pv
```

Expected:

* PVC bound to PV
* backend pod mounts it at `/data`

---

## Scenario 11: HPA test

Apply load generator:

```bash
kubectl apply -f 20-load-generator.yaml
kubectl get hpa -n mesh-lab -w
kubectl top pods -n mesh-lab
```

Expected:

* CPU usage increases
* HPA scales `frontend-blue`

Remove load:

```bash
kubectl delete -f 20-load-generator.yaml
```

---

# 27. Important explanations

---

## 27.1 Why DNS policy is required

Your FQDN-based egress policy:

```yaml
toFQDNs:
  - matchName: www.google.com
```

works only if pods can query DNS.
So even when you want to restrict everything, you still need to allow DNS to CoreDNS / kube-dns.

---

## 27.2 Istio mTLS vs HTTPS

Inside the mesh:

* Istio sidecars handle **mTLS**
* you do **not** manually provide app certs for pod-to-pod traffic in the normal mesh flow
* Istio generates and rotates workload certs automatically

This is different from app-level HTTPS where your application itself terminates TLS.

So for mesh internal traffic:

```text
app container → local Envoy sidecar → mTLS → peer Envoy sidecar → peer app container
```

---

## 27.3 Why Cilium and Istio both are used

They operate at different layers:

### Cilium

* network enforcement
* pod identity at network level
* ingress/egress policy
* FQDN-based egress control

### Istio

* service mesh
* mTLS
* traffic shifting
* blue/green / canary
* retries / timeouts / observability

So together:

* **Cilium** says **who can talk to whom**
* **Istio** says **how traffic should flow and be secured in the mesh**

---

## 27.4 Why MetalLB is needed in kind

Cloud clusters give real LoadBalancers automatically.

kind does not.

So MetalLB simulates cloud-style `LoadBalancer` services by assigning an external IP from your local network range.

That is why:

```text
Istio IngressGateway Service type = LoadBalancer
```

works in kind only after MetalLB is installed.

---

# 28. Real-world edge cases to practice

These are the best edge cases for interviews and real learning.

---

## Edge case 1: Strict mTLS + no sidecar

* mesh workload has sidecar
* another pod without sidecar tries to access it
* traffic fails

This proves strict mTLS enforcement.

---

## Edge case 2: Default deny without DNS allow

* you create default deny
* forget DNS allow
* all FQDN egress tests fail

Very common mistake.

---

## Edge case 3: Ingress works but backend blocked

* external request reaches frontend through gateway
* frontend cannot call backend because Cilium policy missing

This is a very realistic debugging case.

---

## Edge case 4: VirtualService weight change

* blue works
* you shift to green
* green has bug
* revert by just changing weights

This is the core blue-green / canary practice.

---

## Edge case 5: Readiness failure but pod still running

* container is alive
* readiness fails
* pod is removed from service endpoints
* traffic stops going to it

Very important production concept.

---

## Edge case 6: Liveness failure

* liveness fails
* kubelet restarts container
* restart count increases

---

## Edge case 7: HPA not scaling

Common causes:

* metrics-server not working
* no CPU requests set
* wrong target deployment
* too little load

---

## Edge case 8: FQDN policy and redirects

Some external sites redirect to other domains.
If only `www.google.com` is allowed, traffic may fail if app follows redirects to another hostname not allowed by policy.

That is a very practical real-world behavior to remember.

---

# 29. Debugging commands

These are the commands you will repeatedly use.

## Kubernetes basics

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get endpoints -A
kubectl describe pod -n mesh-lab <pod-name>
kubectl logs -n mesh-lab <pod-name> -c istio-proxy
kubectl logs -n mesh-lab <pod-name> -c frontend
kubectl get events -A --sort-by=.lastTimestamp
```

## Istio

```bash
istioctl proxy-status
istioctl analyze
kubectl get peerauthentication,destinationrule,virtualservice,gateway -n mesh-lab
kubectl logs -n istio-system deploy/istiod
```

## Cilium

```bash
kubectl get ciliumnetworkpolicies -n mesh-lab
cilium status
cilium connectivity test
hubble observe
```

## HPA

```bash
kubectl get hpa -n mesh-lab
kubectl describe hpa -n mesh-lab frontend-blue-hpa
kubectl top pod -n mesh-lab
kubectl top node
```

## MetalLB

```bash
kubectl get svc -n istio-system
kubectl get pods -n metallb-system
kubectl logs -n metallb-system deploy/controller
```

---

# 30. Suggested folder structure

```text
istio-cilium-lab/
├── 00-kind-cluster.yaml
├── 01-metallb-pool.yaml
├── 02-namespace.yaml
├── 03-configmap.yaml
├── 04-rbac.yaml
├── 05-pv-pvc.yaml
├── 06-backend.yaml
├── 07-frontend-blue-green.yaml
├── 08-toolbox.yaml
├── 09-istio-mtls.yaml
├── 10-destinationrule.yaml
├── 11-gateway-virtualservice.yaml
├── 12-google-serviceentry.yaml
├── 13-cnp-allow-dns.yaml
├── 14-cnp-default-deny.yaml
├── 15-cnp-allow-ingressgateway-to-frontend.yaml
├── 16-cnp-allow-frontend-to-backend.yaml
├── 17-cnp-toolbox-google-egress.yaml
├── 18-cnp-toolbox-to-apps.yaml
├── 19-hpa.yaml
├── 20-load-generator.yaml
└── 21-no-sidecar-test.yaml
```

---

# 31. What to say in interview / explanation

You can explain this lab like this:

> I built a kind-based Kubernetes lab with Cilium, Istio, and MetalLB to simulate a production-style environment. MetalLB provided external IPs for LoadBalancer services, Istio handled ingress, blue-green routing, and strict mTLS, and Cilium enforced namespace-level default deny, DNS exceptions, pod-to-pod allow rules, and FQDN-based egress so only Google was reachable externally. I also included RBAC with ServiceAccounts, RoleBindings, static PV/PVC storage, probes, ConfigMaps, and HPA to practice both application behavior and platform-level troubleshooting.

---

# 32. What you may have missed

These are optional additions if you want to make it even more production-like later:

* `AuthorizationPolicy` in Istio
* `RequestAuthentication` with JWT
* `NetworkPolicy` comparison with native K8s vs Cilium
* `ServiceMonitor` with Prometheus
* `Grafana` dashboards
* `Kiali`
* `PodDisruptionBudget`
* `ResourceQuota`
* `LimitRange`
* `Ingress TLS` with cert-manager
* `Egress Gateway` in Istio
* `CiliumClusterwideNetworkPolicy`
* `Cilium L7 HTTP policies`

---

# 33. Final mental model

```text
MetalLB
  gives external IP to Istio ingress gateway

Istio
  controls ingress, mTLS, blue-green traffic shifting

Cilium
  controls pod-to-pod ingress/egress and external FQDN access

RBAC
  controls Kubernetes API permissions for workloads

PV/PVC
  provides storage to workloads

Probes
  control pod health and readiness for traffic

HPA
  scales pods based on load
```

---

# 34. Recommended practice order

Best way to learn this deeply:

1. Bring cluster up
2. Install Cilium
3. Install MetalLB
4. Install Istio
5. Deploy namespace + apps
6. Verify traffic with **no policies**
7. Apply DNS allow
8. Apply default deny
9. Add specific allow rules
10. Test Google-only egress
11. Enable strict mTLS
12. Test no-sidecar failure
13. Practice blue-green switch
14. Practice HPA
15. Break probes intentionally
16. Use logs / describe / Hubble to debug

---

# 35. Cleanup

```bash
kubectl delete ns mesh-lab
kubectl delete ns no-mesh
kind delete cluster --name istio-cilium-lab
```

---

# 36. Very important note about kind + hostPath PV

The PV in this lab is for **practice only**.

In real production:

* you usually do **not** use `hostPath`
* you use CSI-backed storage
* you usually create **PVC**, not manual PV
* cloud storage examples:

  * EBS
  * EFS
  * Azure Disk
  * GCE PD

---