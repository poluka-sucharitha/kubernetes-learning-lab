````md
# 🚀 Kong Gateway (Gateway API) + Blue/Green + Canary Deployment — Complete Hands-on Lab

---

# 📌 1. Objective

In this lab, we achieved:

- Install **Kong Ingress Controller** using Helm
- Use **Gateway API (GatewayClass, Gateway, HTTPRoute)**
- Deploy:
  - Blue version of frontend
  - Green version of frontend
- Perform:
  - Path-based routing
  - Blue/Green deployment
  - Canary deployment (traffic splitting)

---

# 🧠 Architecture Overview

```text
Client
   ↓
MetalLB External IP
   ↓
Kong Proxy (LoadBalancer Service)
   ↓
Gateway (Entry Point)
   ↓
HTTPRoute (Routing Rules)
   ↓
Service (ClusterIP)
   ↓
Pod
````

---

# 📌 2. Install Gateway API CRDs (MANDATORY)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
```

Verify:

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

---

# 📌 3. Install Kong using Helm

## Add repo

```bash
helm repo add kong https://charts.konghq.com
helm repo update
```

## Install Kong (IMPORTANT: Enable Gateway API)

```bash
helm upgrade --install kong kong/ingress \
  -n kong \
  --create-namespace \
  --set controller.ingressController.env.feature_gates="GatewayAlpha=true" \
  --wait
```

---

## Verify Installation

```bash
kubectl get pods -n kong
kubectl get svc -n kong
```

Check Gateway API feature:

```bash
kubectl logs -n kong deploy/kong-controller | grep GatewayAlpha
```

Expected:

```text
GatewayAlpha", "enabled": true
```

---

# 📌 4. Create Application Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shop-kong
```

Apply:

```bash
kubectl apply -f 01-shop-kong-namespace.yaml
```

---

# 📌 5. Deploy Blue Version (Frontend)

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-blue
  namespace: shop-kong
  labels:
    app: frontend
    version: blue
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
      containers:
        - name: frontend
          image: hashicorp/http-echo:1.0.0
          args:
            - "-listen=:8080"
            - "-text=frontend-blue"
          ports:
            - containerPort: 8080
```

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-blue
  namespace: shop-kong
spec:
  selector:
    app: frontend
    version: blue
  ports:
    - port: 80
      targetPort: 8080
```

---

# 📌 6. Deploy Green Version (Frontend)

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-green
  namespace: shop-kong
  labels:
    app: frontend
    version: green
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
      containers:
        - name: frontend
          image: hashicorp/http-echo:1.0.0
          args:
            - "-listen=:8080"
            - "-text=frontend-green"
          ports:
            - containerPort: 8080
```

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-green
  namespace: shop-kong
spec:
  selector:
    app: frontend
    version: green
  ports:
    - port: 80
      targetPort: 8080
```

---

# 📌 7. Orders Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders
  namespace: shop-kong
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders
  template:
    metadata:
      labels:
        app: orders
    spec:
      containers:
        - name: orders
          image: hashicorp/http-echo:1.0.0
          args:
            - "-listen=:8080"
            - "-text=orders-service"
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: orders
  namespace: shop-kong
spec:
  selector:
    app: orders
  ports:
    - port: 8080
      targetPort: 8080
```

---

# 📌 8. GatewayClass (VERY IMPORTANT)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong
  annotations:
    konghq.com/gatewayclass-unmanaged: "true"
spec:
  controllerName: konghq.com/kic-gateway-controller
```

Apply:

```bash
kubectl apply -f 08-kong-gatewayclass.yaml
```

---

# 📌 9. Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kong
  namespace: kong
spec:
  gatewayClassName: kong
  listeners:
    - name: proxy
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
```

Apply:

```bash
kubectl apply -f 09-kong-gateway.yaml
```

---

# 📌 10. HTTPRoute (Routing)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-route
  namespace: shop-kong
spec:
  parentRefs:
    - name: kong
      namespace: kong
  hostnames:
    - shop-kong.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /orders
      backendRefs:
        - name: orders
          port: 8080
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: frontend-blue
          port: 80
          weight: 100
```

Apply:

```bash
kubectl apply -f 10-httproute-blue-only.yaml
```

---

# 📌 11. Get External IP

```bash
kubectl get svc -n kong kong-gateway-proxy
```

```bash
export KONG_IP=$(kubectl get svc -n kong kong-gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

---

# 📌 12. Testing

## Frontend

```bash
curl -H "Host: shop-kong.local" http://$KONG_IP/
```

Expected:

```text
frontend-blue
```

## Orders

```bash
curl -H "Host: shop-kong.local" http://$KONG_IP/orders
```

Expected:

```text
orders-service
```

---

# 📌 13. Blue/Green Deployment

Switch to green:

```yaml
backendRefs:
  - name: frontend-green
    port: 80
    weight: 100
```

---

# 📌 14. Canary Deployment

```yaml
backendRefs:
  - name: frontend-blue
    port: 80
    weight: 90
  - name: frontend-green
    port: 80
    weight: 10
```

Test:

```bash
for i in {1..20}; do curl -s -H "Host: shop-kong.local" http://$KONG_IP/; echo; done
```

---

# 📌 15. Debugging Guide (VERY IMPORTANT)

## Check Kong Pods

```bash
kubectl get pods -n kong
```

---

## Check Gateway Status

```bash
kubectl get gateway -n kong
kubectl describe gateway kong -n kong
```

Expected:

```text
Programmed: True
```

---

## Check HTTPRoute

```bash
kubectl get httproute -n shop-kong
kubectl describe httproute shop-route -n shop-kong
```

---

## Check Services

```bash
kubectl get svc -n shop-kong
kubectl get endpoints -n shop-kong
```

---

## Check Logs

```bash
kubectl logs -n kong deploy/kong-controller
```

---

# 🚨 Common Errors

## ❌ "no Route matched"

```text
Cause:
- Gateway not programmed
- HTTPRoute not attached
- Host mismatch
```

---

## ❌ Gateway stuck in "Waiting for controller"

```text
Fix:
- Enable GatewayAlpha
- Add annotation in GatewayClass
```

---

# 🎯 Final Summary

```text
GatewayClass → defines controller (Kong)
Gateway      → defines entry point (port, protocol)
HTTPRoute    → defines routing (path, weight)
Service      → forwards to pods
```

---

# 💡 One-line Summary

```text
Kong Gateway + HTTPRoute enables path routing, blue/green deployment, and canary traffic splitting in Kubernetes.
```

---

```
```


###Namespace used for diffferent levels###

Client
   ↓
MetalLB (metallb-system)
   ↓
Kong Gateway (kong)
   ↓
HTTPRoute (shop-kong)
   ↓
Service (shop-kong)
   ↓
Pod (shop-kong)
