Got it — your issue is just formatting. You need **everything inside ONE markdown code block** so it renders properly.

Here is your **correct, clean `.md` file** 👇

# Kubernetes HPA Practice Guide

## 📌 HPA YAML Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-deployment
  namespace: hpa-practice
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hpa-app
  template:
    metadata:
      labels:
        app: hpa-app
    spec:
      containers:
        - name: hpa-container
          image: nginx
          ports:
            - containerPort: 80
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
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi

---
apiVersion: v1
kind: Service
metadata:
  name: hpa-service
  namespace: hpa-practice
spec:
  selector:
    app: hpa-app
  ports:
    - port: 80
      targetPort: 80

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-autoscaler
  namespace: hpa-practice
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-deployment
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      selectPolicy: Max
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
        - type: Percent
          value: 100
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 0
      selectPolicy: Min
      policies:
        - type: Pods
          value: 1
          periodSeconds: 15
        - type: Percent
          value: 50
          periodSeconds: 15
````

---

## 🚀 Steps to Run

### 1. Save the YAML

```bash
vi hpa.yaml
```

---

### 2. Create Namespace

```bash
kubectl create namespace hpa-practice
```

---

### 3. Verify Metrics Server

```bash
kubectl top nodes
kubectl top pods -n hpa-practice
```

---

### 4. Apply YAML

```bash
kubectl apply -f hpa.yaml
```

---

### 5. Verify Resources

```bash
kubectl get all -n hpa-practice
kubectl get hpa -n hpa-practice
```

---

### 6. Watch HPA

```bash
kubectl get hpa -n hpa-practice -w
```

---

### 7. Watch Pods

```bash
kubectl get pods -n hpa-practice -w
```

---

## 🔥 Generate Load

### Start BusyBox

```bash
kubectl run load-generator -n hpa-practice --image=busybox -it --rm -- /bin/sh
```

---

### Generate Concurrent Traffic

```sh
for i in 1 2 3 4 5 6 7 8 9 10; do
  while true; do
    wget -q -O- http://hpa-service > /dev/null
  done &
done
wait
```

---

## 📊 Verify Scaling

```bash
kubectl describe hpa hpa-autoscaler -n hpa-practice
kubectl top pods -n hpa-practice
```

---

## ⚠️ Important Notes

* HPA works on **CPU / Memory usage**
* It does **NOT scale based on request count**
* Nginx is lightweight → may not trigger strong scaling

---

## 🧠 HPA Formula

```
desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)
```

---

## 🛠️ If Scaling Not Happening

Check:

```bash
kubectl top pods -n hpa-practice
kubectl describe hpa hpa-autoscaler -n hpa-practice
```

Common reasons:

* Metrics Server missing
* Low CPU usage
* Not enough load

---

## 🛑 Stop Load

Press:

```bash
Ctrl + C
```

---

## 📌 Key Takeaways

| Concept      | Meaning         |
| ------------ | --------------- |
| HPA works on | CPU / Memory    |
| Not based on | Requests        |
| nginx issue  | Too lightweight |
| Best testing | CPU-heavy apps  |

```

---

Now this will **render perfectly in GitHub / VS Code / Markdown viewers** ✅

If you want, I can also give you a **CPU stress YAML** so you’ll see scaling instantly (much better for interviews).

