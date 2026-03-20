# 📘 Metrics Server Installation in KIND Cluster (Step-by-Step Guide)

This guide helps you **reliably install Metrics Server in a KIND (Kubernetes IN Docker) cluster**, which is required for:

- `kubectl top`
- HPA (CPU/Memory)
- KEDA CPU & Memory triggers

---

# 🧠 Why Metrics Server Fails in KIND

In KIND or lab clusters, you often see:

```

Metrics API not available
Readiness probe failed: HTTP probe failed with statuscode: 500

````

### Root Cause

- Metrics Server tries to connect to **kubelet securely**
- KIND kubelet certificates are **not trusted**
- Connection fails → Metrics Server becomes **Not Ready**

---

# ✅ Solution Overview

We fix this by adding:

```bash
--kubelet-insecure-tls
--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
````

---

# 🚀 Step-by-Step Installation

---

## 🔹 Step 1: Clean Previous Installation (if exists)

```bash
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 🔹 Step 2: Download Metrics Server YAML

```bash
curl -LO https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 🔹 Step 3: Modify YAML (IMPORTANT)

Open file:

```bash
vi components.yaml
```

Find this section:

```yaml
containers:
- args:
```

Update it like this:

```yaml
containers:
- args:
  - --cert-dir=/tmp
  - --secure-port=10250
  - --kubelet-insecure-tls
  - --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
```

---

## 🔹 Step 4: Apply the YAML

```bash
kubectl apply -f components.yaml
```

---

## 🔹 Step 5: Wait for Pod to Become Ready

```bash
kubectl get pods -n kube-system | grep metrics-server
```

Expected:

```
metrics-server-xxxxx   1/1   Running
```

---

## 🔹 Step 6: Verify Metrics API

```bash
kubectl get apiservices | grep metrics
```

Expected:

```
v1beta1.metrics.k8s.io   True
```

---

## 🔹 Step 7: Test Metrics

```bash
kubectl top nodes
kubectl top pods -A
```

---

# ⚡ One-Command Quick Install (Shortcut)

If you don’t want to edit YAML manually:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"}
]'
```

---

# 🔍 Troubleshooting

---

## ❌ Problem: Pod is Running but Not Ready

Check logs:

```bash
kubectl logs -n kube-system deployment/metrics-server
```

---

## ❌ Problem: Metrics API not available

Check:

```bash
kubectl describe apiservice v1beta1.metrics.k8s.io
```

Look for:

* `False` status
* TLS or connection errors

---

## ❌ Problem: Still not working

Restart rollout:

```bash
kubectl rollout restart deployment metrics-server -n kube-system
```

---

# 🧪 How This Connects to Your Learning

After Metrics Server works:

| Feature             | Depends on Metrics Server |
| ------------------- | ------------------------- |
| `kubectl top`       | ✅                         |
| HPA CPU scaling     | ✅                         |
| HPA Memory scaling  | ✅                         |
| KEDA CPU trigger    | ✅                         |
| KEDA Memory trigger | ✅                         |

---

# ⚠️ Important Note

The flag:

```bash
--kubelet-insecure-tls
```

* ✅ OK for **learning / lab**
* ❌ Not recommended for **production**

---

# 💡 Pro Tip (Reusable Script)

Create a script:

```bash
#!/bin/bash

kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"}
]'
```

Run anytime:

```bash
bash install-metrics-server.sh
```

---

# 🎯 Final Outcome

After successful setup:

```bash
kubectl top nodes
kubectl top pods -A
```
# 📘 KEDA Scaling Flow — Step-by-Step

## 🔄 End-to-End Flow

```text
You define ScaledObject (CRD)
        ↓
KEDA reads triggers
        ↓
KEDA uses corresponding scaler
        ↓
KEDA creates/updates HPA
        ↓
HPA calculates desired replicas
        ↓
Deployment/ReplicaSet updates replica count
        ↓
Scheduler assigns Pods to nodes
        ↓
Kubelet starts containers via CRI


