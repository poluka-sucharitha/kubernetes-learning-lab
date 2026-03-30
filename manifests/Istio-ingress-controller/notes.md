# 🚀 Istio Ingress Gateway + Kubernetes (Complete Hands-on Notes)

---

# 📌 1. Istio Installation

## Install Istio CLI

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
```

## Install Istio (Control Plane + Ingress Gateway)

```bash
istioctl install -y
```

### What this does:

```text
✔ Installs istiod (control plane)
✔ Installs istio-ingressgateway (Envoy + LoadBalancer Service)
```

---

# 📌 2. Namespaces Design (IMPORTANT)

We use **separate namespaces**:

```text
istio-system   → Istio control plane + ingress gateway
shop           → application workloads
```

### Why?

```text
✔ Security isolation
✔ RBAC separation
✔ Better management
✔ Production best practice
```

---

# 📌 3. Enable Istio Sidecar Injection

```bash
kubectl label namespace shop istio-injection=enabled --overwrite
```

👉 This ensures:

```text
All NEW pods in "shop" namespace get istio-proxy sidecar
```

⚠️ Important:

```text
Existing pods will NOT get sidecar → must restart
```

```bash
kubectl rollout restart deployment frontend -n shop
kubectl rollout restart deployment orders -n shop
```

---

# 📌 4. RBAC (Optional but Good Practice)

* ServiceAccount
* Role
* RoleBinding

👉 Used for:

```text
Controlling access (e.g., reading ConfigMaps)
```

---

# 📌 5. Application Setup

## Frontend

* Deployment (nginx)
* Service (ClusterIP)

## Orders

* Deployment (http-echo)
* Service (ClusterIP)

---

# 📌 6. Storage

* PV (PersistentVolume)
* PVC (PersistentVolumeClaim)

👉 Used for:

```text
Persisting application data
```

---

# 📌 7. Istio Gateway (ENTRY POINT)

## Purpose:

```text
Defines how traffic ENTERS the cluster
```

## Example:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: shop-gateway
  namespace: shop
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        protocol: HTTP
      hosts:
        - shop.local
```

---

## Key Concepts

```text
Gateway:
✔ Checks Host (domain)
✔ Checks Port (80/443)
✔ Allows traffic
❌ Does NOT route traffic
```

---

# 📌 8. VirtualService (ROUTING)

## Purpose:

```text
Routes traffic to services
```

## Example:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: shop-vs
  namespace: shop
spec:
  hosts:
    - shop.local
  gateways:
    - shop-gateway
  http:
    - match:
        - uri:
            prefix: /orders
      route:
        - destination:
            host: orders
            port:
              number: 8080
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: frontend
            port:
              number: 80
```

---

## Key Concepts

```text
VirtualService:
✔ Matches path (/orders, /)
✔ Routes to service
✔ Uses service DNS (NOT ClusterIP directly)
```

---

# 📌 9. Traffic Flow (FULL)

```text
Client
  ↓
DNS (shop.local → LB IP)
  ↓
LoadBalancer (MetalLB)
  ↓
Istio Ingress Gateway (Envoy)
  ↓
Gateway (host + port check)
  ↓
VirtualService (routing)
  ↓
Service (ClusterIP)
  ↓
Pod
```

---

# 📌 10. Autoscaling

## HPA

```text
✔ CPU / Memory based scaling
```

## KEDA

```text
✔ Event-driven scaling
✔ External metrics (SQS, Kafka, etc.)
```

---

# 📌 11. Network Policies (Cilium + K8s)

## Default Deny

```yaml
kind: NetworkPolicy
```

```text
❌ Blocks all traffic (Ingress + Egress)
```

## Allow Rules

```text
✔ istio-ingressgateway → frontend
✔ frontend → orders
```

---

# ⚠️ IMPORTANT LEARNING

```text
NetworkPolicy can break Istio traffic if not configured correctly
```

---

# 🧪 DEBUGGING GUIDE (VERY IMPORTANT)

---

## 1️⃣ Check Istio Installation

```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

---

## 2️⃣ Check Gateway + VirtualService

```bash
kubectl get gateway,virtualservice -n shop
```

---

## 3️⃣ Check Pods (Sidecar Injection)

```bash
kubectl get pods -n shop
```

Expected:

```text
frontend → 2/2
orders → 2/2
```

---

## 4️⃣ If pods show 1/1

```bash
kubectl rollout restart deployment frontend -n shop
kubectl rollout restart deployment orders -n shop
```

---

## 5️⃣ Check Services + Endpoints

```bash
kubectl get svc -n shop
kubectl get endpoints -n shop
```

---

## 6️⃣ Test Inside Cluster

```bash
kubectl run tmp --rm -it --image=busybox -n shop -- sh
wget -qO- http://frontend
wget -qO- http://orders:8080
```

---

## 7️⃣ Test External

```bash
kubectl get svc istio-ingressgateway -n istio-system

curl -H "Host: shop.local" http://<EXTERNAL-IP>/
curl -H "Host: shop.local" http://<EXTERNAL-IP>/orders
```

---

## 8️⃣ Common Errors

### ❌ 404 NR

```text
Gateway/VirtualService mismatch
```

---

### ❌ Connection Timeout

```text
Backend unreachable
```

Causes:

```text
✔ NetworkPolicy blocking
✔ Service not reachable
✔ Pod not healthy
```

---

## 9️⃣ Fix Network Policy Issues

```bash
kubectl delete networkpolicy default-deny-all -n shop
kubectl delete ciliumnetworkpolicy -n shop --all
```

---

## 10️⃣ Check Logs

```bash
kubectl logs -n istio-system deploy/istio-ingressgateway
kubectl logs -n shop deploy/frontend -c istio-proxy
kubectl logs -n shop deploy/orders -c istio-proxy
```

---

# 🎯 FINAL UNDERSTANDING

```text
istioctl install → installs gateway (Envoy + LB)

Gateway YAML → allows traffic (host + port)

VirtualService → routes traffic

Service → forwards to pod
```

---

# 💡 ONE-LINE SUMMARY

```text
Istio Gateway handles incoming traffic entry, VirtualService routes traffic to services, and Kubernetes services forward traffic to pods.

