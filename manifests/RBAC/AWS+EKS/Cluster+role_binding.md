# 🔐 EKS IAM → Access Entry → RBAC (End-to-End Hands-on Guide)

## 📌 Goal

Understand and implement:

- Create EKS cluster
- Create IAM user
- Give IAM user access to cluster
- Control access using RBAC
- Test pod access

---

# 🧱 Step 1: Create EKS Cluster

```bash
eksctl create cluster \
  --name my-cluster \
  --region ap-south-1 \
  --without-nodegroup
````

---

## Create Nodegroup

```bash
eksctl create nodegroup \
  --cluster my-cluster \
  --region ap-south-1 \
  --name my-nodes \
  --node-type t3.small \
  --nodes 1
```

---

## Verify Cluster

```bash
kubectl get nodes
```

---

# 🔐 Step 2: Create IAM User

Create IAM user:

```text
User name: test
Access type: Programmatic access
```

---

## Configure AWS CLI Profile

```bash
aws configure --profile test
```

Verify:

```bash
aws sts get-caller-identity --profile test
```

Expected:

```text
arn:aws:iam::<account-id>:user/test
```

---

# 🔌 Step 3: Connect IAM User to Cluster (kubeconfig)

```bash
aws eks update-kubeconfig \
  --name my-cluster \
  --region ap-south-1 \
  --profile test \
  --kubeconfig /tmp/test-kubeconfig
```

---

## Test Access (Before Mapping)

```bash
kubectl --kubeconfig /tmp/test-kubeconfig get nodes
```

### Output:

```text
Unauthorized ❌
```

---

# 🧠 Concept

```text
IAM configured → Authentication OK
BUT cluster does not know user → Unauthorized
```

---

# 🔗 Step 4: Create Access Entry (IAM → EKS Mapping)

```bash
aws eks create-access-entry \
  --cluster-name my-cluster \
  --principal-arn arn:aws:iam::<account-id>:user/test \
  --type STANDARD \
  --region ap-south-1
```

---

## Test Again

```bash
kubectl --kubeconfig /tmp/test-kubeconfig get nodes
```

### Output:

```text
Forbidden ❌
```

---

# 🧠 Concept

```text
EKS knows user (Authentication OK)
BUT no permissions → Forbidden
```

---

# ⚡ Step 5: Grant Permissions (EKS Policy)

```bash
aws eks associate-access-policy \
  --cluster-name my-cluster \
  --principal-arn arn:aws:iam::<account-id>:user/test \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region ap-south-1
```

---

## Test Again

```bash
kubectl --kubeconfig /tmp/test-kubeconfig get nodes
```

### Output:

```text
Works ✅
```

---

# 🧠 Concept

```text
Authentication ✅
Authorization via EKS Policy ✅
```

---

# 🔥 Step 6: Remove EKS Policy (Switch to RBAC)

```bash
aws eks disassociate-access-policy \
  --cluster-name my-cluster \
  --principal-arn arn:aws:iam::<account-id>:user/test \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --region ap-south-1
```

---

## Test

```bash
kubectl --kubeconfig /tmp/test-kubeconfig get nodes
```

### Output:

```text
Forbidden ❌
```

---

# 🧩 Step 7: Apply RBAC

## Create Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

Apply:

```bash
kubectl apply -f role.yaml
```

---

## Create RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: default
subjects:
- kind: User
  name: arn:aws:iam::<account-id>:user/test
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```bash
kubectl apply -f rolebinding.yaml
```

---

# 🧪 Step 8: Test Access

## ✅ Allowed

```bash
kubectl --kubeconfig /tmp/test-kubeconfig get pods -n default
```

---

## ❌ Not Allowed

```bash
kubectl --kubeconfig /tmp/test-kubeconfig delete pod <pod-name> -n default
```

---

## ❌ Cluster Level

```bash
kubectl --kubeconfig /tmp/test-kubeconfig get nodes
```

---

# 🧠 Final Understanding

```text
IAM → Authentication
Access Entry → Mapping
RBAC → Authorization
```

---

# 🔥 Error Understanding

| Error        | Meaning          |
| ------------ | ---------------- |
| Unauthorized | No access entry  |
| Forbidden    | No permissions   |
| Works        | Fully configured |

---


| Component    | Purpose              |
| ------------ | -------------------- |
| IAM          | Identity             |
| kubeconfig   | Login setup          |
| Access Entry | Mapping              |
| EKS Policy   | Broad permissions    |
| RBAC         | Fine-grained control |


# 🚀 Final Summary

```text
update-kubeconfig = login setup
create-access-entry = connect IAM to cluster
associate-access-policy = quick admin access
RBAC = real production control
```

