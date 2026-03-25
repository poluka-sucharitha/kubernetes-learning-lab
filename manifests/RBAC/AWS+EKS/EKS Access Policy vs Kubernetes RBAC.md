Here’s your **clean GitHub-ready `.md` file** with everything structured clearly 👇

````md
# EKS Access Policy vs Kubernetes RBAC (Role & RoleBinding)

## 📌 Overview

In Amazon EKS, access control involves **two major layers**:

1. **Authentication** → Who are you?
2. **Authorization** → What are you allowed to do?

These are handled using:
- **IAM + Access Entry (EKS)**
- **EKS Access Policies OR Kubernetes RBAC**

---

# 🔐 Authentication vs Authorization

| Layer | Purpose | Tool |
|------|--------|------|
| Authentication | Verify identity | IAM + Access Entry |
| Authorization | Define permissions | EKS Access Policy OR RBAC |

---

# ⚖️ Difference: EKS Access Policy vs RBAC

## 🟢 1. EKS Access Policy

### 🔹 What it is
AWS-managed way to grant Kubernetes permissions.

### 🔹 Command used
```bash
aws eks associate-access-policy
````

### 🔹 Example

```bash
aws eks associate-access-policy \
  --cluster-name prod-cluster \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:user/dev-user \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=namespace,namespaces=prod-app \
  --region ap-south-1
```

### 🔹 Features

* AWS-managed (no YAML needed)
* Quick to configure
* Supports:

  * Cluster-wide access
  * Namespace-level access
* Limited customization

### 🔹 Limitations

* Cannot restrict specific resources (e.g., only pods)
* Cannot define custom rules

---

## 🔵 2. Kubernetes RBAC (Role & RoleBinding)

### 🔹 What it is

Native Kubernetes authorization system.

### 🔹 Components

* **Role** → Defines permissions
* **RoleBinding** → Assigns permissions to user/group/service account

### 🔹 Example

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: prod-app
  name: readonly-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: readonly-binding
  namespace: prod-app
subjects:
- kind: User
  name: dev-readonly
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: readonly-role
  apiGroup: rbac.authorization.k8s.io
```

### 🔹 Features

* Fine-grained control
* Can restrict:

  * Specific resources (pods, secrets, etc.)
  * Specific actions (get, create, delete)
* Fully customizable

### 🔹 Limitations

* Requires YAML management
* Slightly complex

---

# 🔥 Key Differences

| Feature          | EKS Access Policy   | Kubernetes RBAC            |
| ---------------- | ------------------- | -------------------------- |
| Managed by       | AWS                 | Kubernetes                 |
| Setup            | CLI command         | YAML                       |
| Scope            | Cluster / Namespace | Namespace + Resource-level |
| Customization    | Limited             | Full control               |
| Ease of use      | Easy                | Moderate                   |
| Production usage | Basic cases         | Advanced control           |

---

# 🔄 Flow in EKS Cluster

## 🧠 Step-by-step Flow

```text
IAM User / Role
        ↓
IAM Policy (optional AWS permissions)
        ↓
EKS Access Entry
        ↓
Authentication to Kubernetes API
        ↓
Authorization via:
    → EKS Access Policy
    OR
    → Kubernetes RBAC
        ↓
Access granted / denied
```

---

## 📌 Detailed Explanation

### Step 1: IAM Identity

* User or role created in AWS

### Step 2: Access Entry

```bash
aws eks create-access-entry
```

* Registers IAM identity with EKS
* Enables authentication

### Step 3: Authorization (Choose one)

#### Option A: EKS Access Policy

```bash
aws eks associate-access-policy
```

* AWS handles permissions

#### Option B: RBAC

```yaml
Role + RoleBinding
```

* Kubernetes handles permissions

---

# 🔄 Flow in Kubernetes Cluster (Generic K8s)

## 🧠 Step-by-step Flow

```text
User / ServiceAccount
        ↓
Authentication (certificate/token)
        ↓
API Server
        ↓
RBAC Check (Role / ClusterRole)
        ↓
Access granted / denied
```

---

## 📌 Detailed Explanation

### Step 1: Identity

* User (certificate/token)
* ServiceAccount (for pods)

### Step 2: Authentication

* Verified by API server

### Step 3: Authorization

* Checked via RBAC

---

# 🔥 EKS vs Kubernetes Flow Comparison

| Step          | Kubernetes          | EKS                |
| ------------- | ------------------- | ------------------ |
| Identity      | User/SA             | IAM User/Role      |
| Auth          | Certificates/Tokens | IAM + Access Entry |
| Authorization | RBAC                | RBAC or EKS Policy |
| Integration   | Manual              | AWS integrated     |

---

# 🎯 When to Use What

## Use EKS Access Policy when:

* You want quick setup
* You don’t need fine control
* Basic read/write access is enough

## Use RBAC when:

* You need fine-grained control
* You want namespace-specific + resource-specific permissions
* Production-level security is required

---

# 💡 Best Practice

```text
Use BOTH together:

IAM → Authentication
RBAC → Fine-grained Authorization
```

---

# 🚀 Final Summary

* **Access Entry** → Authentication
* **EKS Access Policy** → Simple AWS-managed authorization
* **RBAC** → Advanced Kubernetes-native authorization

```text
EKS Flow:

IAM → Access Entry → (Access Policy OR RBAC)
```

```text
Kubernetes Flow:

User → Auth → RBAC
```

---

# 🔥 Key Takeaway

👉 Authentication and Authorization are separate
👉 Access Entry ≠ Permissions
👉 RBAC = Most powerful control
👉 EKS Policy = Simplified AWS control


