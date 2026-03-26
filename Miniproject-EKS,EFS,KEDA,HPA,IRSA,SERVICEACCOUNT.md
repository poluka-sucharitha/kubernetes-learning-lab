**Phase 1 — cluster**



**You already did most of this, so just confirm:**



**EKS cluster is up**

**worker nodes are Ready**

**OIDC is enabled**

**kubectl get nodes works
==========================================================================================================================================================**



eksctl get nodegroup --cluster my-cluster --region ap-south-1



eksctl scale nodegroup \\

&#x20; --cluster my-cluster \\

&#x20; --name my-nodes \\

&#x20; --nodes 2 \\

&#x20; --nodes-min 1 \\

&#x20; --nodes-max 2 \\

&#x20; --region ap-south-1



kubectl get nodes

eksctl get nodegroup --cluster my-cluster --region ap-south-1



aws eks describe-nodegroup \\

&#x20; --cluster-name my-cluster \\

&#x20; --nodegroup-name my-nodes \\

&#x20; --region ap-south-1



\-----------------------------------------------

**cluster yaml file with private subnet and oidc**


apiVersion: eksctl.io/v1alpha5

kind: ClusterConfig



metadata:

&#x20; name: prod-cluster

&#x20; region: ap-south-1

&#x20; version: "1.34"



availabilityZones:

&#x20; - ap-south-1a

&#x20; - ap-south-1b

&#x20; - ap-south-1c



iam:

&#x20; withOIDC: true



managedNodeGroups:

&#x20; - name: private-ng

&#x20;   instanceType: t3.small

&#x20;   desiredCapacity: 2

&#x20;   minSize: 2

&#x20;   maxSize: 2

&#x20;   privateNetworking: true



\-----------------------------------------------------

kubectl get nodes -o wide

kubectl get nodes -L topology.kubernetes.io/zone



aws eks describe-cluster --name prod-cluster --region ap-south-1



aws ec2 describe-subnets   --subnet-ids subnet-0d2322e0a62500011 subnet-0c020bbe7f7eaa4fe subnet-014743b02adc053b6 subnet-027ba4b2146f052c7 subnet-0b09e526876b8a951 subnet-072173f1ceeaf092e   --region ap-south-1


aws ec2 describe-security-groups   --group-ids sg-08d7b000f6f2709d5 sg-0e3d805a83b0f7eb4   --region ap-south-1



aws ec2 describe-subnets   --subnet-ids subnet-0d2322e0a62500011 subnet-0c020bbe7f7eaa4fe subnet-014743b02adc053b6 subnet-027ba4b2146f052c7 subnet-0b09e526876b8a951 subnet-072173f1ceeaf092e   --region ap-south-1   --query 'Subnets\[\*].{SubnetId:SubnetId,AZ:AvailabilityZone,PublicIP:MapPublicIpOnLaunch,Name:Tags\[?Key==`Name`]|\[0].Value,RoleELB:Tags\[?Key==`kubernetes.io/role/elb`]|\[0].Value,RoleInternalELB:Tags\[?Key==`kubernetes.io/role/internal-elb`]|\[0].Value}'



=====================================================================================================================================================================================

**Phase 2 — shared storage with EFS**



**Do this next:**



**create EFS**

**create mount targets in EKS subnets**

**allow NFS 2049 from worker node SG to EFS SG**

**install EFS CSI driver**

**create StorageClass**

**create PVC**

**mount same PVC into 2 pods**

**write file in pod1**

**read same file in pod2**

**=============================================================================================================================================================================================================**

**EFS FILESYSTEM CREATION:**
-----------------------

aws efs create-file-system \\

&#x20; --creation-token prod-cluster-efs \\

&#x20; --performance-mode generalPurpose \\

&#x20; --throughput-mode bursting \\

&#x20; --encrypted \\

&#x20; --tags Key=Name,Value=prod-cluster-efs \\

&#x20; --region ap-south-1


export EFS\_ID=<your-file-system-id>

**Create a security group for EFS** 

\--------------------------------
aws ec2 create-security-group \\

&#x20; --group-name prod-cluster-efs-sg \\

&#x20; --description "EFS mount target SG for prod-cluster" \\

&#x20; --vpc-id vpc-079d1e14f1053befa \\

&#x20; --region ap-south-1



export EFS\_SG=sg-083764d2f402b6962



**Allow NFS from worker nodes to EFS:
-----------------------------------**
aws ec2 authorize-security-group-ingress \\

&#x20; --group-id $EFS\_SG \\

&#x20; --protocol tcp \\

&#x20; --port 2049 \\

&#x20; --source-group sg-0e3d805a83b0f7eb4 \\

&#x20; --region ap-south-1





**Create mount targets in your private subnets:
----------------------------------------------
ap-south-1a**
aws efs create-mount-target \\

&#x20; --file-system-id $EFS\_ID \\

&#x20; --subnet-id subnet-027ba4b2146f052c7 \\

&#x20; --security-groups $EFS\_SG \\

&#x20; --region ap-south-1

**ap-south-1c**
aws efs create-mount-target \\

&#x20; --file-system-id $EFS\_ID \\

&#x20; --subnet-id subnet-072173f1ceeaf092e \\

&#x20; --security-groups $EFS\_SG \\

&#x20; --region ap-south-1

**ap-south-1b**
aws efs create-mount-target \\

&#x20; --file-system-id $EFS\_ID \\

&#x20; --subnet-id subnet-0b09e526876b8a951 \\

&#x20; --security-groups $EFS\_SG \\

&#x20; --region ap-south-1


**Check mount targets:
---------------------**
aws efs describe-mount-targets \\

&#x20; --file-system-id $EFS\_ID \\

&#x20; --region ap-south-1


You created:



AWS EFS file system

This is the AWS-managed NFS service

In Kubernetes/EKS practice, when we say “AWS NFS”, we usually mean EFS

A separate security group for EFS

sg-083764d2f402b6962

This SG is attached to the EFS mount targets

An ingress rule on the EFS SG

Allow TCP 2049

Source = worker node SG sg-0e3d805a83b0f7eb4

Mount targets in private subnets

one in ap-south-1a

one in ap-south-1b

one in ap-south-1c



**UNDERSTANDING:**
---------------

We are creating AWS NFS (EFS), and allowing NFS traffic from EKS worker nodes to EFS.
=======================================================================================================================================================================================


**IRSA:(Pod → ServiceAccount → IAM Role → EFS)**

eksctl create iamserviceaccount \\

&#x20; --name efs-csi-controller-sa \\

&#x20; --namespace kube-system \\

&#x20; --cluster prod-cluster \\

&#x20; --region ap-south-1 \\

&#x20; --role-name AmazonEKS\_EFS\_CSI\_DriverRole \\

&#x20; --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \\

&#x20; --approve

**Next step: install the EFS CSI add-on:**

\---------------------------------------

The official EKS add-on name is aws-efs-csi-driver.



**Run this:**



aws eks create-addon \\

&#x20; --cluster-name prod-cluster \\

&#x20; --addon-name aws-efs-csi-driver \\

&#x20; --service-account-role-arn arn:aws:iam::088206884714:role/AmazonEKS\_EFS\_CSI\_DriverRole \\

&#x20; --region ap-south-1



**Then check status:**



aws eks describe-addon \\

&#x20; --cluster-name prod-cluster \\

&#x20; --addon-name aws-efs-csi-driver \\

&#x20; --region ap-south-1



**And also verify in Kubernetes:**



kubectl get pods -n kube-system | grep efs





================================================================================================================================================
**create storage class and pvc:
-----------------------------

1) StorageClass + PVC**



Save as efs-sc-pvc.yaml



apiVersion: storage.k8s.io/v1

kind: StorageClass

metadata:

&#x20; name: efs-sc

provisioner: efs.csi.aws.com

parameters:

&#x20; provisioningMode: efs-ap

&#x20; fileSystemId: fs-REPLACE\_ME

&#x20; directoryPerms: "700"

&#x20; basePath: "/dynamic\_provisioning"

reclaimPolicy: Delete

volumeBindingMode: Immediate



\---

apiVersion: v1

kind: PersistentVolumeClaim

metadata:

&#x20; name: efs-pvc

spec:

&#x20; accessModes:

&#x20;   - ReadWriteMany

&#x20; storageClassName: efs-sc

&#x20; resources:

&#x20;   requests:

&#x20;     storage: 5Gi





**Replace this:**

**fileSystemId: fs-REPLACE\_ME**





Apply it:

\---------

kubectl apply -f efs-sc-pvc.yaml

kubectl get sc

kubectl get pvc

kubectl get pv



PVC should become Bound.



**2) Two pods using the same PVC**



Save as efs-test-pods.yaml



apiVersion: v1

kind: Pod

metadata:

&#x20; name: efs-app1

&#x20; labels:

&#x20;   app: efs-app1

spec:

&#x20; containers:

&#x20;   - name: app1

&#x20;     image: busybox

&#x20;     command: \["/bin/sh", "-c", "sleep 36000"]

&#x20;     volumeMounts:

&#x20;       - name: efs-volume

&#x20;         mountPath: /data

&#x20; volumes:

&#x20;   - name: efs-volume

&#x20;     persistentVolumeClaim:

&#x20;       claimName: efs-pvc



\---

apiVersion: v1

kind: Pod

metadata:

&#x20; name: efs-app2

&#x20; labels:

&#x20;   app: efs-app2

spec:

&#x20; containers:

&#x20;   - name: app2

&#x20;     image: busybox

&#x20;     command: \["/bin/sh", "-c", "sleep 36000"]

&#x20;     volumeMounts:

&#x20;       - name: efs-volume

&#x20;         mountPath: /data

&#x20; volumes:

&#x20;   - name: efs-volume

&#x20;     persistentVolumeClaim:

&#x20;       claimName: efs-pvc



**Apply:**



kubectl apply -f efs-test-pods.yaml

kubectl get pods -o wide


You may see them on different nodes. That is fine.



**How to test from one pod to another:
====================================**

**Write file from pod 1**

kubectl exec -it efs-app1 -- /bin/sh



**Inside pod1:**



cd /data

echo "hello from pod1" > test1.txt

cat test1.txt

hostname > created-by.txt

ls -l /data

exit

Read same file from pod 2

kubectl exec -it efs-app2 -- /bin/sh



**Inside pod2:**



cd /data

cat test1.txt

cat created-by.txt

ls -l /data

exit



If pod2 can read the file created by pod1, your EFS shared storage is working.

======================================================================================================================================================================================

**Phase 3 — human access control**



**Then add RBAC:**



**platform-admin → full cluster access**

**dev-readonly → only get/list/watch in prod-app**



**Use:**



**EKS access entry for authentication**

**Kubernetes Role + RoleBinding for namespace authorization**



**AWS explicitly notes that if predefined access policies don’t fit your needs, using Kubernetes groups with native RBAC is the right pattern**

**======================================================================================================================================================================================================================**



Create 3 identities:



1.platform-admin

Full cluster access for you.

2.dev-readonly

Can only view resources in prod-app.

3.app-serviceaccount

Used by the worker deployment.



For humans:



Create an EKS access entry for the IAM user/role.

Associate an EKS access policy if needed.

Then apply Kubernetes RBAC for namespace-level restrictions.



For pods:



Create a Kubernetes ServiceAccount

Map it to an IAM role using IRSA

Grant only SQS read permissions to that IAM role
===========================================================================================================================================================================

**🚀 PART 1 — Namespace Setup**

kubectl create namespace prod-app

**🚀 PART 2 — platform-admin (FULL ACCESS)**



👉 This is YOU (IAM user)



**Step 1: Create access entry**

aws eks create-access-entry \\

&#x20; --cluster-name prod-cluster \\

&#x20; --principal-arn arn:aws:iam::<ACCOUNT\_ID>:user/<YOUR\_USER> \\

&#x20; --region ap-south-1

Step 2: Attach admin policy

aws eks associate-access-policy \\

&#x20; --cluster-name prod-cluster \\

&#x20; --principal-arn arn:aws:iam::<ACCOUNT\_ID>:user/<YOUR\_USER> \\

&#x20; --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \\

&#x20; --access-scope type=cluster \\

&#x20; --region ap-south-1



✅ Now you are cluster admin



**🚀 PART 3 — dev-readonly (LIMITED ACCESS)**



👉 Goal: Only view resources inside prod-app



**Step 1: Create IAM user**

aws iam create-user --user-name dev-readonly



Attach minimal policy (for EKS auth only):



aws iam attach-user-policy \\

&#x20; --user-name dev-readonly \\

&#x20; --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

Step 2: Add access entry

aws eks create-access-entry \\

&#x20; --cluster-name prod-cluster \\

&#x20; --principal-arn arn:aws:iam::<ACCOUNT\_ID>:user/dev-readonly \\

&#x20; --region ap-south-1

Step 3: Kubernetes RBAC (IMPORTANT 🔥)



**Create file: dev-readonly-rbac.yaml**

\-----------------------------------

apiVersion: rbac.authorization.k8s.io/v1

kind: Role

metadata:

&#x20; namespace: prod-app

&#x20; name: readonly-role

rules:

\- apiGroups: \[""]

&#x20; resources: \["pods", "services", "configmaps"]

&#x20; verbs: \["get", "list", "watch"]



\---



apiVersion: rbac.authorization.k8s.io/v1

kind: RoleBinding

metadata:

&#x20; name: readonly-binding

&#x20; namespace: prod-app

subjects:

\- kind: User

&#x20; name: dev-readonly

&#x20; apiGroup: rbac.authorization.k8s.io

roleRef:

&#x20; kind: Role

&#x20; name: readonly-role

&#x20; apiGroup: rbac.authorization.k8s.io



**Apply:**



kubectl apply -f dev-readonly-rbac.yaml





\-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Phase 4 — pod identity with IRSA**



**Then:**



**create SQS queue**

**create IAM policy with only SQS consumer permissions**

**create app-serviceaccount**

**bind it to IAM role with IRSA**

**test from inside pod using aws sts get-caller-identity**

**confirm SQS works**

**confirm unrelated AWS access like S3 fails
============================================================================================================================================================================================**

Yes — you can do this. One important correction first:



`aws sqs list-queues` will \*\*not\*\* work with the policy you shared, because `ListQueues` is a different permission and is not included there. Also, most SQS actions support queue-level permissions, so for a proper production-style test it is better to allow access to \*\*one specific queue ARN\*\* instead of `"Resource": "\*"`. (\[AWS Documentation]\[1])



Here is the clean flow to perform IRSA on your `prod-cluster`.



\## 1) Pre-checks



Make sure these work first:



```bash

kubectl get nodes

aws sts get-caller-identity

eksctl version

```



Your cluster must also have an \*\*OIDC provider associated\*\*, because IRSA depends on that. AWS documents IRSA as mapping an IAM role to a Kubernetes service account so Pods can get AWS credentials without using the node role. (\[AWS Documentation]\[2])



Check OIDC:



```bash

aws eks describe-cluster \\

&#x20; --name prod-cluster \\

&#x20; --region ap-south-1 \\

&#x20; --query "cluster.identity.oidc.issuer" \\

&#x20; --output text

```



If it returns a URL, good.



If not enabled, run:



```bash

eksctl utils associate-iam-oidc-provider \\

&#x20; --cluster prod-cluster \\

&#x20; --region ap-south-1 \\

&#x20; --approve

```



\## 2) Create namespace



If `prod-app` is not already there:



```bash

kubectl create namespace prod-app

```



\## 3) Create a test SQS queue



Create one queue so you can test permissions properly.



```bash

aws sqs create-queue \\

&#x20; --queue-name prod-irsa-test-queue \\

&#x20; --region ap-south-1

```



Get the queue URL:



```bash

aws sqs get-queue-url \\

&#x20; --queue-name prod-irsa-test-queue \\

&#x20; --region ap-south-1

```



Get the queue ARN:



```bash

aws sqs get-queue-attributes \\

&#x20; --queue-url https://sqs.ap-south-1.amazonaws.com/<ACCOUNT\_ID>/prod-irsa-test-queue \\

&#x20; --attribute-names QueueArn \\

&#x20; --region ap-south-1

```



Save this ARN. Example:



```bash

arn:aws:sqs:ap-south-1:<ACCOUNT\_ID>:prod-irsa-test-queue

```



\## 4) Create IAM policy for SQS



Create `sqs-policy.json`



```json

{

&#x20; "Version": "2012-10-17",

&#x20; "Statement": \[

&#x20;   {

&#x20;     "Effect": "Allow",

&#x20;     "Action": \[

&#x20;       "sqs:ReceiveMessage",

&#x20;       "sqs:DeleteMessage",

&#x20;       "sqs:GetQueueAttributes",

&#x20;       "sqs:GetQueueUrl"

&#x20;     ],

&#x20;     "Resource": "arn:aws:sqs:ap-south-1:<ACCOUNT\_ID>:prod-irsa-test-queue"

&#x20;   }

&#x20; ]

}

```



Create the policy:



```bash

aws iam create-policy \\

&#x20; --policy-name SQSReadPolicy \\

&#x20; --policy-document file://sqs-policy.json

```



If the policy already exists, get its ARN with:



```bash

aws iam list-policies \\

&#x20; --scope Local \\

&#x20; --query "Policies\[?PolicyName=='SQSReadPolicy'].Arn" \\

&#x20; --output text

```



\## 5) Create IAM ServiceAccount using eksctl



AWS/eksctl supports creating the IAM role and Kubernetes service account together for IRSA. (\[AWS Documentation]\[3])



Run:



```bash

eksctl create iamserviceaccount \\

&#x20; --name app-serviceaccount \\

&#x20; --namespace prod-app \\

&#x20; --cluster prod-cluster \\

&#x20; --attach-policy-arn arn:aws:iam::<ACCOUNT\_ID>:policy/SQSReadPolicy \\

&#x20; --approve \\

&#x20; --region ap-south-1

```



\## 6) Verify the ServiceAccount



```bash

kubectl get sa app-serviceaccount -n prod-app -o yaml

```



You should see an annotation like:



```yaml

annotations:

&#x20; eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT\_ID>:role/...

```



That annotation is the main proof that the service account is linked to an IAM role for IRSA. (\[AWS Documentation]\[4])



\## 7) Create the IRSA test Pod



Create `irsa-test.yaml`



```yaml

apiVersion: v1

kind: Pod

metadata:

&#x20; name: irsa-test

&#x20; namespace: prod-app

spec:

&#x20; serviceAccountName: app-serviceaccount

&#x20; containers:

&#x20;   - name: aws-cli

&#x20;     image: amazon/aws-cli:latest

&#x20;     command: \["/bin/sh", "-c"]

&#x20;     args:

&#x20;       - sleep 3600

```



Apply it:



```bash

kubectl apply -f irsa-test.yaml

kubectl get pod -n prod-app

```



Wait until it is `Running`.



\## 8) Enter the Pod and test identity



```bash

kubectl exec -it irsa-test -n prod-app -- sh

```



Inside the Pod:



```bash

aws sts get-caller-identity

```



You should see an \*\*assumed role ARN\*\*, not the node IAM role. That is the key proof that IRSA is working. AWS explains that apps in Pods use the IAM role associated with the Kubernetes service account instead of relying on node credentials. (\[AWS Documentation]\[2])



It will look similar to:



```text

arn:aws:sts::<ACCOUNT\_ID>:assumed-role/<role-name>/<session-name>

```



\## 9) Test allowed SQS permissions



Still inside the Pod, use your queue URL:



```bash

aws sqs get-queue-url \\

&#x20; --queue-name prod-irsa-test-queue \\

&#x20; --region ap-south-1

```



Then:



```bash

aws sqs get-queue-attributes \\

&#x20; --queue-url https://sqs.ap-south-1.amazonaws.com/<ACCOUNT\_ID>/prod-irsa-test-queue \\

&#x20; --attribute-names All \\

&#x20; --region ap-south-1

```



This should work.



You can also try receive-message:



```bash

aws sqs receive-message \\

&#x20; --queue-url https://sqs.ap-south-1.amazonaws.com/<ACCOUNT\_ID>/prod-irsa-test-queue \\

&#x20; --region ap-south-1

```



It may return no messages if the queue is empty, but permission-wise it should succeed.



\## 10) Test denied action



Inside the Pod:



```bash

aws s3 ls

```



This should fail with `AccessDenied`, which proves the Pod only has SQS permissions.



\## 11) One very important production note



Sometimes Pods can still reach the \*\*node role\*\* through IMDS if IMDS access is not restricted. AWS notes that Pods should use the service-account role, but node-role exposure can still matter depending on instance metadata access patterns. In production, people usually harden this so workloads cannot fall back to the node role unintentionally. (\[AWS Documentation]\[2])



\## 12) Cleanup



Exit the Pod shell, then:



```bash

kubectl delete pod irsa-test -n prod-app

```



If you want to delete the service account and IAM role created by eksctl:



```bash

eksctl delete iamserviceaccount \\

&#x20; --name app-serviceaccount \\

&#x20; --namespace prod-app \\

&#x20; --cluster prod-cluster \\

&#x20; --region ap-south-1

```



Delete policy if needed:



```bash

aws iam delete-policy \\

&#x20; --policy-arn arn:aws:iam::<ACCOUNT\_ID>:policy/SQSReadPolicy

```



Delete queue if needed:



```bash

aws sqs delete-queue \\

&#x20; --queue-url https://sqs.ap-south-1.amazonaws.com/<ACCOUNT\_ID>/prod-irsa-test-queue \\

&#x20; --region ap-south-1

```



\## What you are proving with this lab



This lab proves:



\* Kubernetes Pod uses `app-serviceaccount`

\* `app-serviceaccount` is mapped to an IAM role

\* IAM role has only SQS permissions

\* Pod gets AWS credentials through IRSA

\* Pod can access SQS

\* Pod cannot access unrelated AWS services like S3



That is exactly the real production concept of IRSA.



I can also turn this into a clean GitHub-ready `.md` file with commands, expected outputs, and troubleshooting.



\[1]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-api-permissions-reference.html?utm\_source=chatgpt.com "Amazon SQS API permissions: Actions and resource ..."

\[2]: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html?utm\_source=chatgpt.com "IAM roles for service accounts"

\[3]: https://docs.aws.amazon.com/eks/latest/eksctl/iamserviceaccounts.html?utm\_source=chatgpt.com "IAM Roles for Service Accounts - Eksctl User Guide"

\[4]: https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html?utm\_source=chatgpt.com "Assign IAM roles to Kubernetes service accounts"

=======================================================================================================================================================================================


**# 🚀 Phase 5 — KEDA + SQS Autoscaling (EKS)**



\## 🧠 What you’re building



```plaintext

SQS queue → KEDA → HPA → Deployment scaling



More messages → more pods

No messages → scale to 0

```



\---



\# 🔹 Step 0 — Prerequisites (VERY IMPORTANT)



Make sure:



\* ✅ EKS cluster running

\* ✅ IRSA configured (your `app-serviceaccount`)

\* ✅ IAM role has SQS permissions

\* ✅ OIDC enabled



\---



\# 🔹 Step 1 — Install KEDA



```bash

helm repo add kedacore https://kedacore.github.io/charts

helm repo update



helm install keda kedacore/keda \\

&#x20; --namespace keda \\

&#x20; --create-namespace

```



Check:



```bash

kubectl get pods -n keda

```



You should see:



\* keda-operator

\* metrics-apiserver



\---



\# 🔹 Step 2 — Create SQS Queue



```bash

aws sqs create-queue --queue-name my-keda-queue

```



Get Queue URL:



```bash

aws sqs get-queue-url --queue-name my-keda-queue

```



👉 Save this (important)



\---



\# 🔹 Step 3 — Deploy Worker App (uses ServiceAccount)



\## 📄 worker-deployment.yaml



```yaml

apiVersion: apps/v1

kind: Deployment

metadata:

&#x20; name: sqs-worker

&#x20; namespace: prod-app

spec:

&#x20; replicas: 1

&#x20; selector:

&#x20;   matchLabels:

&#x20;     app: sqs-worker

&#x20; template:

&#x20;   metadata:

&#x20;     labels:

&#x20;       app: sqs-worker

&#x20;   spec:

&#x20;     serviceAccountName: app-serviceaccount   # IRSA here 🔥

&#x20;     containers:

&#x20;     - name: worker

&#x20;       image: busybox

&#x20;       command:

&#x20;         - /bin/sh

&#x20;         - -c

&#x20;         - |

&#x20;           while true; do

&#x20;             echo "Polling SQS..."

&#x20;             sleep 10

&#x20;           done

```



Apply:



```bash

kubectl apply -f worker-deployment.yaml

```



\---



\# 🔹 Step 4 — Create KEDA ScaledObject



\## 📄 scaledobject.yaml



```yaml

apiVersion: keda.sh/v1alpha1

kind: ScaledObject

metadata:

&#x20; name: sqs-scaler

&#x20; namespace: prod-app

spec:

&#x20; scaleTargetRef:

&#x20;   name: sqs-worker



&#x20; minReplicaCount: 0

&#x20; maxReplicaCount: 10



&#x20; triggers:

&#x20; - type: aws-sqs-queue

&#x20;   metadata:

&#x20;     queueURL: https://sqs.ap-south-1.amazonaws.com/<ACCOUNT\_ID>/my-keda-queue

&#x20;     awsRegion: ap-south-1

&#x20;     queueLength: "5"   # scale when >5 messages



&#x20;   authenticationRef:

&#x20;     name: keda-aws-auth

```



\---



\# 🔹 Step 5 — Create TriggerAuthentication (IRSA)



\## 📄 trigger-auth.yaml



```yaml

apiVersion: keda.sh/v1alpha1

kind: TriggerAuthentication

metadata:

&#x20; name: keda-aws-auth

&#x20; namespace: prod-app

spec:

&#x20; podIdentity:

&#x20;   provider: aws

```



👉 This tells KEDA:



> "Use IAM role from ServiceAccount (IRSA)"



\---



Apply both:



```bash

kubectl apply -f trigger-auth.yaml

kubectl apply -f scaledobject.yaml

```



\---



\# 🔹 Step 6 — Verify KEDA Created HPA



```bash

kubectl get hpa -n prod-app

```



👉 You should see:



```plaintext

keda-hpa-sqs-scaler

```



\---



\# 🔹 Step 7 — Test Scaling 🚀



\## 🔸 Initially (no messages)



```bash

kubectl get pods -n prod-app

```



👉 Expected:



\* 0 pods (after cooldown)



\---



\## 🔸 Push messages to SQS



```bash

aws sqs send-message \\

&#x20; --queue-url <QUEUE\_URL> \\

&#x20; --message-body "test message"

```



Send multiple:



```bash

for i in {1..20}; do

&#x20; aws sqs send-message \\

&#x20;   --queue-url <QUEUE\_URL> \\

&#x20;   --message-body "msg-$i"

done

```



\---



\## 🔸 Watch scaling



```bash

kubectl get pods -n prod-app -w

```



👉 You will see:



```plaintext

1 → 2 → 3 → ... pods increasing

```



\---



\## 🔸 Check HPA metrics



```bash

kubectl describe hpa -n prod-app

```



\---



\# 🔹 Step 8 — Scale Down Test



After messages are processed:



```bash

kubectl get pods -n prod-app -w

```



👉 Pods go:



```plaintext

5 → 3 → 1 → 0

```



\---



\# 🔥 FULL FLOW (VERY IMPORTANT)



```plaintext

SQS queue ↑

&#x20;  ↓

KEDA polls queue

&#x20;  ↓

KEDA sends metrics to HPA

&#x20;  ↓

HPA scales deployment

&#x20;  ↓

Pods process messages

&#x20;  ↓

Queue drains

&#x20;  ↓

KEDA scales to 0

```



\---



\# 🔥 KEY PRODUCTION INSIGHTS



\### ✅ Why IRSA is used



\* No AWS keys in pods

\* Secure access to SQS



\---



\### ✅ Why minReplicaCount = 0



\* Saves cost 💰

\* True event-driven



\---



\### ✅ queueLength



```plaintext

queueLength = threshold



Example:

5 messages → 1 pod

10 messages → 2 pods

```



\---



\### ✅ Difference from HPA



| Feature     | HPA | KEDA |

| ----------- | --- | ---- |

| CPU based   | ✅   | ✅    |

| Event based | ❌   | ✅    |

| Scale to 0  | ❌   | ✅    |



\---



\# ⚠️ Common Mistakes (YOU WILL HIT THESE 😄)



\### ❌ Pods not scaling



\* Check:



```bash

kubectl logs -n keda deploy/keda-operator

```



\---



\### ❌ IRSA not working



\* ServiceAccount not linked to IAM role

\* Missing OIDC



\---



\### ❌ Wrong queue URL



\* Must be exact



\---



\### ❌ No HPA created



```bash

kubectl get scaledobject -n prod-app

```



\---



\# 🧠 FINAL UNDERSTANDING



```plaintext

IRSA → gives pod AWS access

KEDA → reads SQS metrics

HPA → scales pods

Deployment → runs workers

```



\---



\# 🔥 If you want next level (HIGHLY RECOMMENDED)



I can help you extend this into:



\* ✅ Real app consuming SQS (Python/Node)

\* ✅ Visibility timeout handling

\* ✅ Dead-letter queue (DLQ)

\* ✅ KEDA + Prometheus combo

\* ✅ Production architecture diagram



Just tell me 👍



