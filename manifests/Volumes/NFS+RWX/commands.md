# IMPORTANT

- create EKS AND NFS in the same vpc and sg group

```plaintext
EFS → CSI Driver → StorageClass → PVC (RWX) → Multiple Pods → Shared Data
```

---

# 🚀 STEP-BY-STEP: RWX Practice in EKS (EFS)

---

## 🟢 Step 1: Install EFS CSI Driver

```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
```

Verify:

```bash
kubectl get pods -n kube-system | grep efs
```

---

## 🟢 Step 2: Create EFS in AWS

Go to AWS Console:

👉 EFS → Create File System

Important:

* Same VPC as EKS
* Enable mount targets in all AZs

After creation, copy:

👉 **File System ID**
Example: `fs-12345678`

---

## 🟢 Step 3: Create StorageClass (RWX)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678   # <-- replace
  directoryPerms: "700"
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

Apply:

```bash
kubectl apply -f sc.yaml
```

---

## 🟢 Step 4: Create PVC (RWX)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany   # 🔥 THIS IS RWX
  storageClassName: efs-sc
  resources:
    requests:
      storage: 1Gi
```

Apply:

```bash
kubectl apply -f pvc.yaml
kubectl get pvc
```

---

## 🟢 Step 5: Create TWO Pods using SAME PVC

### Pod 1

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod1
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - mountPath: /data
      name: shared-vol
  volumes:
  - name: shared-vol
    persistentVolumeClaim:
      claimName: efs-pvc
```

---

### Pod 2

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod2
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - mountPath: /data
      name: shared-vol
  volumes:
  - name: shared-vol
    persistentVolumeClaim:
      claimName: efs-pvc
```

Apply:

```bash
kubectl apply -f pod1.yaml
kubectl apply -f pod2.yaml
```

---

## 🟢 Step 6: Test RWX (MOST IMPORTANT 🔥)

### Write from pod1

```bash
kubectl exec -it pod1 -- sh

cd /data
echo "Hello from pod1" > test.txt
exit
```

---

### Read from pod2

```bash
kubectl exec -it pod2 -- sh

cd /data
cat test.txt
```

👉 ✅ You should see:

```plaintext
Hello from pod1
```

---

## 🎯 What just happened?

```plaintext
Both pods → same PVC → same EFS → shared filesystem
```

✔ Multiple pods
✔ Even on different nodes
✔ Same data

👉 THIS = RWX

---

# 🔍 Step 7: Verify Internals (Important for interview)

```bash
kubectl get pv
kubectl describe pvc efs-pvc
kubectl describe pod pod1
```

---

# 🔥 Final Understanding

| Type | Works with    | Access           |
| ---- | ------------- | ---------------- |
| EBS  | Block storage | ❌ RWX (only RWO) |
| EFS  | File storage  | ✅ RWX            |

---

# 🧠 Super Important Interview Line

👉
**"RWX requires shared file system (like EFS), not block storage (like EBS)"**

# Note

RWX  → many pods (EFS use case)
RWO  → one node (EBS use case)
RWOP → exactly one pod (strict control)


### Mistake I made during EFS RWX practice
- I created EKS and EFS in different VPCs.
- Later, I selected the wrong security group for EFS.
- Because of that, the PVC got created and bound, but the Pod could not mount the EFS volume.
- The final issue was network connectivity on NFS port 2049 between the EKS node and EFS mount target.
- so create nfs and eks in the smae vpc with sam sg (security group)