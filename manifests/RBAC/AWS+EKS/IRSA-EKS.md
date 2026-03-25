# 🚀 IRSA (IAM Roles for Service Accounts) — Complete Guide

## 📌 What is IRSA?

**IRSA (IAM Roles for Service Accounts)** is a feature in AWS EKS that allows a **Kubernetes Pod** to securely access AWS services (like SQS, S3, DynamoDB) using an **IAM Role**.

👉 Instead of using node-level permissions, each Pod can get its **own IAM role**.

---

## 🎯 Why IRSA is Needed

### ❌ Without IRSA (Old Approach)
- IAM role is attached to EC2 node
- All pods on that node share the same permissions
- Security risk ❗

👉 Example:
If node has S3 + SQS access → **every pod can access both**

---

### ✅ With IRSA (Best Practice)
- Each Pod gets its own IAM role
- Permissions are isolated
- Follows **Least Privilege Principle**

👉 Example:
- Pod A → only SQS access
- Pod B → only S3 access

---

## 🧠 Core Concepts

### 1. Pod
Your application running inside Kubernetes.

---

### 2. ServiceAccount (Kubernetes Identity)
- Represents identity of a Pod inside Kubernetes
- Pod uses this to interact with API server
- In IRSA, this is the bridge to AWS

---

### 3. IAM Role (AWS Identity)
- Contains AWS permissions (SQS, S3, etc.)
- Attached to ServiceAccount using IRSA

---

### 4. OIDC Provider
- Trust bridge between EKS and AWS IAM
- Allows Kubernetes to authenticate with AWS

---

## 🔁 IRSA Flow (VERY IMPORTANT 🔥)

```

Pod starts
↓
Uses ServiceAccount
↓
ServiceAccount is annotated with IAM Role
↓
EKS uses OIDC provider
↓
AWS STS gives temporary credentials
↓
Pod uses credentials to call AWS (SQS/S3)

```

---

## 🔍 Real-Time Example (Your Case)

### Goal:
Pod should access **SQS only**

---

### Step-by-step flow:

1. Create IAM Policy (SQS permissions)
2. Create IAM Role
3. Link IAM Role → ServiceAccount
4. Run Pod with that ServiceAccount
5. Pod gets temporary AWS credentials
6. Pod can access SQS

---

## 📦 Architecture View

```

```
      AWS IAM
         │
 IAM Role (SQS access)
         │
  (Trust via OIDC)
         │
```

Kubernetes ServiceAccount
│
Pod
│
AWS SQS

````

---

## 🔐 Key Feature: Temporary Credentials

- Pod does NOT store credentials
- AWS provides **temporary credentials via STS**
- Automatically rotated
- More secure than access keys

---

## ⚠️ Important Production Notes

### 1. Least Privilege
Always restrict:
- Specific actions
- Specific resource (Queue ARN)

---

### 2. Do NOT use "*"
Bad practice:
```json
"Resource": "*"
````

Good practice:

```json
"Resource": "arn:aws:sqs:ap-south-1:123456789012:my-queue"
```

---

### 3. IMDS Risk (Advanced)

* Pods might access node role if IMDS is open
* In production, restrict IMDS access

---

## 🔥 IRSA vs EKS Access Entry + RBAC

This is VERY IMPORTANT (Interview + Real-time)

---

### 🟢 IRSA (For Pods)

| Feature  | IRSA                |
| -------- | ------------------- |
| Used for | Pods / Workloads    |
| Purpose  | Access AWS services |
| Example  | SQS, S3, DynamoDB   |
| Identity | ServiceAccount      |
| Auth     | IAM Role via OIDC   |

👉 Example:
Pod reads messages from SQS

---

### 🔵 EKS Access Entry + RBAC (For Humans)

| Feature  | EKS Access + RBAC         |
| -------- | ------------------------- |
| Used for | Users / Admins            |
| Purpose  | Access Kubernetes cluster |
| Example  | kubectl get pods          |
| Identity | IAM User / Role           |
| Auth     | kubeconfig + RBAC         |

👉 Example:
Dev runs:

```
kubectl get pods
```

---

## 🧠 Key Difference (Simple Understanding)

```
IRSA → Pod → AWS
RBAC → User → Kubernetes
```

---

## 🔄 End-to-End Comparison

| Scenario                     | What is Used          |
| ---------------------------- | --------------------- |
| Pod accessing SQS            | IRSA                  |
| Pod accessing S3             | IRSA                  |
| User accessing cluster       | RBAC                  |
| Jenkins deploying app        | RBAC                  |
| Pod accessing Kubernetes API | ServiceAccount + RBAC |

---

## ❓ Your Understanding (From Practice)

> "Since pods have to access SQS, we are creating ServiceAccount and giving permission"

### ✔️ Correct Understanding

Refined version:

👉 Pod uses ServiceAccount
👉 ServiceAccount is mapped to IAM Role
👉 IAM Role has SQS permissions

---

## 🎯 Final Summary

* IRSA gives **AWS permissions to Pods**
* ServiceAccount acts as identity inside Kubernetes
* IAM Role provides AWS permissions
* OIDC connects Kubernetes to AWS
* Pod gets **temporary credentials**
* Ensures **secure and isolated access**

---

## 🚀 One-Line Memory Trick

👉 **Pod → ServiceAccount → IAM Role → AWS Service**

---

## 💡 Real-Time Use Cases

* Microservice reading from SQS
* App uploading images to S3
* Lambda-like workloads inside Kubernetes
* Event-driven architectures (KEDA + SQS)

---

## 🧾 Commands You Practiced

```bash
eksctl create iamserviceaccount \
  --name app-serviceaccount \
  --namespace prod-app \
  --cluster prod-cluster \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/SQSReadPolicy \
  --approve
```


```yaml
serviceAccountName: app-serviceaccount
```

eksctl create iamserviceaccount = ServiceAccount + IAM Role (NOT IAM user)

eksctl = IAM Role + ServiceAccount + Mapping (all in one)
---

## 🎉 Final Conclusion

IRSA is one of the **most important production concepts in EKS** because:

* It removes dependency on node IAM roles
* Provides fine-grained access control
* Secures workloads
* Is widely used in real-world architectures




