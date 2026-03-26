# 🚀 COMPLETE FLOW — KEDA + SQS + IRSA (EKS)

---

# 🔹 STEP 0 — Prerequisites

Make sure:

```bash
aws sts get-caller-identity
kubectl get nodes
```

---

# 🔹 STEP 1 — Create Namespace

```bash
kubectl create namespace prod-app
```

---

# 🔹 STEP 2 — Create SQS Queue

```bash
aws sqs create-queue --queue-name my-keda-queue --region ap-south-1
```

Get URL:

```bash
aws sqs get-queue-url \
  --queue-name my-keda-queue \
  --region ap-south-1
```

👉 Save queue URL

---

# 🔹 STEP 3 — Create IAM Policy (SQS Access)

Create file:

```bash
cat > sqs-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": "arn:aws:sqs:ap-south-1:<ACCOUNT_ID>:my-keda-queue"
    }
  ]
}
EOF
```

Create policy:

```bash
aws iam create-policy \
  --policy-name SQSFullAccessKedaDemo \
  --policy-document file://sqs-policy.json \
  --region ap-south-1
```

---

# 🔹 STEP 4 — Create IRSA for APP (worker pods)

```bash
eksctl create iamserviceaccount \
  --name app-serviceaccount \
  --namespace prod-app \
  --cluster prod-cluster \
  --region ap-south-1 \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/SQSFullAccessKedaDemo \
  --approve
```

---

# 🔹 STEP 5 — Install KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace
```

Verify:

```bash
kubectl get pods -n keda
```

---

# 🔹 STEP 6 — Create IRSA for KEDA (VERY IMPORTANT 🔥)

```bash
eksctl create iamserviceaccount \
  --name keda-operator \
  --namespace keda \
  --cluster prod-cluster \
  --region ap-south-1 \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/SQSFullAccessKedaDemo \
  --override-existing-serviceaccounts \
  --approve
```

Restart KEDA:

```bash
kubectl rollout restart deployment keda-operator -n keda
```

---

# 🔹 STEP 7 — Verify ServiceAccounts

```bash
kubectl get sa -n prod-app
kubectl get sa -n keda
```

Check annotations:

```bash
kubectl get sa app-serviceaccount -n prod-app -o yaml
kubectl get sa keda-operator -n keda -o yaml
```

👉 BOTH must have:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::...
```

---

# 🔹 STEP 8 — Create Worker Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sqs-worker
  namespace: prod-app
spec:
  replicas: 0
  selector:
    matchLabels:
      app: sqs-worker
  template:
    metadata:
      labels:
        app: sqs-worker
    spec:
      serviceAccountName: app-serviceaccount
      containers:
      - name: worker
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "Working..."
            sleep 10
          done
```

Apply:

```bash
kubectl apply -f worker.yaml
```

---

# 🔹 STEP 9 — Create TriggerAuthentication

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: keda-aws-auth
  namespace: prod-app
spec:
  podIdentity:
    provider: aws
```

Apply:

```bash
kubectl apply -f trigger-auth.yaml
```

---

# 🔹 STEP 10 — Create ScaledObject

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sqs-scaler
  namespace: prod-app
spec:
  scaleTargetRef:
    name: sqs-worker

  minReplicaCount: 0
  maxReplicaCount: 10

  triggers:
  - type: aws-sqs-queue
    metadata:
      queueURL: https://sqs.ap-south-1.amazonaws.com/<ACCOUNT_ID>/my-keda-queue
      awsRegion: ap-south-1
      queueLength: "5"
    authenticationRef:
      name: keda-aws-auth
```

Apply:

```bash
kubectl apply -f scaledobject.yaml
```

---

# 🔹 STEP 11 — Verify HPA

```bash
kubectl get hpa -n prod-app
```

---

# 🔹 STEP 12 — Send Messages 🚀

```bash
for i in {1..50}; do
  aws sqs send-message \
    --queue-url https://sqs.ap-south-1.amazonaws.com/<ACCOUNT_ID>/my-keda-queue \
    --message-body "msg-$i" \
    --region ap-south-1
done
```

---

# 🔹 STEP 13 — Watch Scaling

```bash
kubectl get pods -n prod-app -w
```

👉 Expected:

```plaintext
0 → 2 → 5 → 10 pods
```

---

# 🔹 STEP 14 — Check Queue

```bash
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names ApproximateNumberOfMessages \
  --region ap-south-1
```

---

# 🔹 STEP 15 — Scale Down Test

```bash
aws sqs purge-queue \
  --queue-url <QUEUE_URL> \
  --region ap-south-1
```

Watch:

```bash
kubectl get pods -n prod-app -w
```

👉 Expected:

```plaintext
10 → 5 → 2 → 0
```

---

# 🔥 FINAL ARCHITECTURE

```plaintext
SQS Queue
   ↓
KEDA (uses IRSA)
   ↓
External Metrics API
   ↓
HPA
   ↓
Deployment
   ↓
Pods (use IRSA)
```

---

# 🚨 COMMON ERRORS (YOU FACED THESE)

| Issue              | Reason                 |
| ------------------ | ---------------------- |
| AccessDenied       | KEDA not using IRSA    |
| No pods            | ServiceAccount missing |
| `<unknown>` metric | KEDA can't read SQS    |
| No scaling         | wrong queue URL        |

---

# 🧠 FINAL UNDERSTANDING

```plaintext
KEDA = reads queue
HPA = decides scale
Deployment = creates pods
IRSA = gives AWS access for pods to read SQS queue length

KEDA operator needs AWS access to read SQS queue length
worker pod would need AWS access only if it actually receives/deletes SQS messages