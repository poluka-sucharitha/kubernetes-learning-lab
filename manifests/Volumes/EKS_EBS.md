# 🚀 EKS + EBS PVC (Auto Mode) – End-to-End Lab Guide

## 📌 Goal
Create an AWS EKS cluster, configure storage using EBS, and verify PersistentVolumeClaim (PVC) read/write.

---

# 🧠 Architecture Overview

```

EKS Cluster (Auto Mode)
↓
Node Pools (system / general-purpose)
↓
StorageClass (EBS CSI)
↓
PVC (request storage)
↓
PV (auto-created EBS volume)
↓
Pod mounts volume → /data

````

---

# 🏗️ Step 1: Create EKS Cluster (AWS UI)

1. Go to **AWS Console → EKS**
2. Click **Create Cluster**
3. Fill:
   - Name → `ebs-lab1`
   - Version → default
   - IAM Role → **Create recommended role**

---

## 🔌 Networking

- Use default VPC
- Select all subnets
- Ensure:
  - Internet Gateway attached
  - Public access enabled

---

## ⚙️ Add-ons (IMPORTANT)

Enable:

- ✅ **Amazon EBS CSI Driver**

---

## 🖥️ Step 2: Add Node Group

1. Go to **Compute → Add Node Group**
2. Fill:
   - Name → `ng-1`
   - Instance type → `t3.medium`
   - Nodes → 2
3. IAM Role → **Create recommended role**

---

# 🔑 Step 3: Configure kubectl

On EC2:

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name ebs-lab1
````

Verify:

```bash
kubectl get nodes
```

---

# ⚠️ Issue 1: API Timeout

### ❌ Error

```
i/o timeout (172.31.x.x)
```

### ✅ Fix

Enable:

```
EKS → Networking → Endpoint access
→ Public access: ENABLED
```

---

# ⚠️ Issue 2: AWS CLI not installed

### ❌ Error

```
aws: command not found
```

### ✅ Fix

```bash
sudo apt update
sudo apt install -y unzip curl

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws --version
```

---

# ⚠️ Issue 3: PVC Provisioner mismatch

### ❌ Wrong

```yaml
provisioner: ebs.csi.aws.com
```

### ✅ Correct (Auto Mode)

```yaml
provisioner: ebs.csi.eks.amazonaws.com
```

---

# ⚠️ Issue 4: Pod not scheduling

### ❌ Error

```
node(s) had untolerated taint(s)
```

### 🔍 Reason

* `system` node pool → tainted (`CriticalAddonsOnly`)
* Pod cannot run there

### ✅ Fix

Use nodeSelector:

```yaml
nodeSelector:
  karpenter.sh/nodepool: general-purpose
```

---

# 🧾 Step 4: Final Working YAML

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc-auto
provisioner: ebs.csi.eks.amazonaws.com
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mypvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc-auto
  resources:
    requests:
      storage: 1Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-deployment
  template:
    metadata:
      labels:
        app: nginx-deployment
    spec:
      nodeSelector:
        karpenter.sh/nodepool: general-purpose
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
          volumeMounts:
            - name: mypvc
              mountPath: /data
      volumes:
        - name: mypvc
          persistentVolumeClaim:
            claimName: mypvc
```

---

# 🚀 Step 5: Apply YAML

```bash
kubectl apply -f ebs-auto.yaml
```

---

# 🔍 Step 6: Verify

```bash
kubectl get sc
kubectl get pvc
kubectl get pv
kubectl get pods
kubectl describe pvc mypvc
```

---

# ✅ Expected Output

```
PVC → Bound
PV → Created
Pod → Running
```

---

# 📂 Step 7: Verify Read/Write

```bash
kubectl exec -it deploy/myapp-deployment -- sh
```

Inside pod:

```bash
cd /data
echo "hello from ebs" > test.txt
cat test.txt
exit
```

Verify again:

```bash
kubectl exec -it deploy/myapp-deployment -- cat /data/test.txt
```

---

# 🧹 Step 8: Cleanup

```bash
kubectl delete -f ebs-auto.yaml
```

---

# 🧠 Key Learnings

### Storage Flow

```
StorageClass → PVC → PV → Pod
```

---

### EKS Auto Mode Differences

| Feature     | Standard EKS    | Auto Mode                 |
| ----------- | --------------- | ------------------------- |
| Provisioner | ebs.csi.aws.com | ebs.csi.eks.amazonaws.com |
| Node mgmt   | Manual          | Automatic (Karpenter)     |
| Node pools  | Custom          | system + general-purpose  |

---

### volumeBindingMode

```
WaitForFirstConsumer
→ Pod scheduled first
→ Then volume created
```

---

### Node Pools

| Pool            | Purpose       | Taint |
| --------------- | ------------- | ----- |
| system          | Core services | Yes   |
| general-purpose | Apps          | No    |

---

# 🎯 Final Understanding

```
Pod scheduling → decides AZ
→ PVC triggers EBS creation
→ PV gets bound
→ Volume mounted to container



