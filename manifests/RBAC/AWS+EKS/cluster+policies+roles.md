# 🔐 EKS Access Control – Quick Notes
## 📌 Core Concept

```text
IAM → Authentication
Access Entry → Mapping
RBAC / EKS Policy → Authorization
````

---

# 🧠 1. kubeconfig

## What it does

* Connects kubectl to cluster
* Uses AWS CLI to get token

```text
kubectl → kubeconfig → aws eks get-token → IAM
```

## Key point

```text
kubeconfig = login setup (NOT permissions)
```

---

# 🧠 2. IAM (Authentication)

## Purpose

* Identifies user

```bash
aws sts get-caller-identity
```

## Key point

```text
IAM = WHO you are
```

---

# 🧠 3. Access Entry (Mapping)

## Purpose

* Links IAM user → EKS cluster

```bash
aws eks create-access-entry ...
```

## Without this

```text
kubectl → Unauthorized ❌
```

## Key point

```text
Access Entry = EKS knows you
```

---

# 🧠 4. Authorization Options

## Option 1: EKS Access Policy

```bash
aws eks associate-access-policy ...
```

### Example

* AmazonEKSClusterAdminPolicy

### Key point

```text
AWS-managed permissions (quick setup)
```

---

## Option 2: RBAC (Kubernetes)

### Role

```yaml
kind: Role
```

### RoleBinding

```yaml
kind: RoleBinding
```

### Key point

```text
RBAC = fine-grained control
```

---

# 🧠 5. Error Understanding

| Error        | Meaning          |
| ------------ | ---------------- |
| Unauthorized | No access entry  |
| Forbidden    | No permissions   |
| Works        | Fully configured |

---

# 🧠 6. Real Flow

```text
kubectl
   ↓
kubeconfig
   ↓
IAM authentication
   ↓
Access Entry
   ↓
RBAC / EKS Policy
   ↓
Access granted / denied
```

---

# 🧠 7. Important Differences

| Component    | Purpose              |
| ------------ | -------------------- |
| IAM          | Identity             |
| kubeconfig   | Login setup          |
| Access Entry | Mapping              |
| EKS Policy   | Broad permissions    |
| RBAC         | Fine-grained control |

---

# 🧠 8. Production Usage

## Admin

```text
Access Entry + EKS Admin Policy
```

## Developers

```text
Access Entry + RBAC
```

## Read-only

```text
Access Entry + RBAC or View Policy
```

---

# 🔥 Final Summary

```text
kubeconfig → login
Access Entry → connect IAM to cluster
RBAC / Policy → control access
```

---

# 🚀 One-Line Memory

```text
Authentication + Mapping + Authorization = EKS Access
