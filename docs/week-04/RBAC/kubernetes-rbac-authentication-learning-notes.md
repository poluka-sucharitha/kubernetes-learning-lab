# Kubernetes RBAC & Authentication — Detailed Learning Notes

## Overview

These notes convert the full conversation into structured beginner-friendly learning notes for GitHub reference. The focus is on understanding how Kubernetes controls access using:

- ServiceAccounts
- Roles
- RoleBindings
- ClusterRoles
- ClusterRoleBindings
- Authentication vs Authorization
- RBAC rule fields like `apiGroups`, `resources`, and `verbs`
- Practical testing with `kubectl auth can-i`

The goal is not just to memorize definitions, but to understand how all these parts work together in real Kubernetes usage.

---

## 1. RBAC — What it means in Kubernetes

### Definition

**RBAC** stands for **Role-Based Access Control**.

It is the Kubernetes authorization system used to decide:

- who can access the Kubernetes API
- what resource they can access
- what action they can perform
- in which namespace or scope they can do it

### Detailed explanation (simple language)

Kubernetes does not allow every user or pod to do everything. Instead, Kubernetes checks permissions before allowing an action.

For example:

- Can this pod list other pods?
- Can Jenkins create a deployment?
- Can this user read secrets?
- Can this identity see namespaces across the cluster?

RBAC answers these questions.

A simple way to think about RBAC is:

```plaintext
Identity + Permission Definition + Binding = Access
```

That means:

- first there must be an identity
- then there must be permissions
- then those permissions must be attached to the identity

### Example (real-world)

In an office:

- employee ID card = identity
- HR read permission = role
- assigning HR read permission to employee = binding

In Kubernetes:

- ServiceAccount or User = identity
- Role or ClusterRole = permission definition
- RoleBinding or ClusterRoleBinding = attachment

### My doubt (if any from chat)

The main confusion was around what each RBAC object actually does and how they relate.

### Clarification given

The conversation clarified the full flow as:

```plaintext
User / Pod
   ↓
ServiceAccount (identity)
   ↓
Role / ClusterRole (permissions)
   ↓
RoleBinding / ClusterRoleBinding (attach permissions)
```

### Final understanding

RBAC is Kubernetes authorization. It controls what an identity is allowed to do.

---

## 2. Authentication vs Authorization

### Definition

- **Authentication** = Who are you?
- **Authorization** = What are you allowed to do?

### Detailed explanation (simple language)

Kubernetes access happens in two stages.

#### Step 1: Authentication
Kubernetes first checks the identity.

Examples:

- Is this request coming from a ServiceAccount token?
- Is this a real user certificate?
- Is this an OIDC login token?

#### Step 2: Authorization
After identity is known, Kubernetes checks RBAC.

Examples:

- Can this identity read pods?
- Can this identity list namespaces?
- Can this identity delete deployments?

So Kubernetes first decides **who you are**, and then decides **what you can do**.

### Example (real-world)

When entering an office building:

- security checks your ID card = authentication
- security checks which rooms you can enter = authorization

### My doubt (if any from chat)

There was confusion about “creating a user” versus simply testing permissions with `--as`.

### Clarification given

The discussion clarified that:

- `kubectl auth can-i` mostly helps test authorization
- `--as` is impersonation, not actual user creation
- real users usually come from an external authentication method

### Final understanding

Authentication proves identity. Authorization checks permissions.

---

## 3. ServiceAccount

### Definition

A **ServiceAccount** is a Kubernetes identity mainly used by pods and workloads.

### Detailed explanation (simple language)

Pods need identity when they talk to the Kubernetes API server.

That identity is usually a ServiceAccount.

Important points:

- ServiceAccounts are Kubernetes objects
- they are namespaced
- every namespace gets a default ServiceAccount automatically
- pods use a ServiceAccount to authenticate

If a pod does not mention a ServiceAccount explicitly, it normally uses the `default` ServiceAccount of that namespace.

That is why ServiceAccounts are often described as:

```plaintext
Identity for pods and in-cluster applications
```

### Example (YAML)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: rbac-demo
```

Pod using that ServiceAccount:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: rbac-demo
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: curlimages/curl:8.8.0
    command: ["sleep", "3600"]
```

### My doubt (if any from chat)

You asked whether a pod can talk to the API server even without creating a ServiceAccount.

### Clarification given

Yes, a pod can still talk to the API server, but then it normally uses the default ServiceAccount.

That is why in production it is better to:

- create a custom ServiceAccount
- give it only the minimum required permissions

### Final understanding

A ServiceAccount is the identity of a pod or in-cluster application. It does not automatically give permissions. Permissions come only through RBAC bindings.

---

## 4. Role

### Definition

A **Role** defines permissions within a **single namespace**.

### Detailed explanation (simple language)

A Role is a permission document.

It says things like:

- can read pods
- can create configmaps
- can update deployments

But a Role works only inside one namespace.

That means if a Role is created in namespace `rbac-demo`, its rules apply only there.

### Example (YAML)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-demo
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

### Real-world example

This is like saying:

- this employee can read files
- but only in one department

### My doubt (if any from chat)

You were trying to understand whether Role is for “inside pod” access.

### Clarification given

No. Role is not about “inside pod” or “outside pod”.

It is about **namespace scope**.

### Final understanding

Role means permissions limited to one namespace.

---

## 5. RoleBinding

### Definition

A **RoleBinding** attaches a Role to an identity.

That identity can be:

- a ServiceAccount
- a User
- a Group

### Detailed explanation (simple language)

A Role by itself only defines permissions. It does not give those permissions to anyone.

A RoleBinding is what actually grants the permissions.

Without RoleBinding:

- Role exists
- rules exist
- but nobody is using them

### Example (YAML)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: rbac-demo
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

### Real-world example

The office has a permission policy document, but RoleBinding is the actual assignment letter that says:

```plaintext
Give this policy to this employee
```

### My doubt (if any from chat)

You were understanding the flow between ServiceAccount, Role, and RoleBinding.

### Clarification given

The flow was simplified to:

```plaintext
ServiceAccount = who
Role = what allowed
RoleBinding = connects both
```

### Final understanding

RoleBinding is the object that grants namespaced permissions to an identity.

---

## 6. ClusterRole

### Definition

A **ClusterRole** defines permissions that are either:

- cluster-wide, or
- for cluster-scoped resources

### Detailed explanation (simple language)

ClusterRole is similar to Role, but it is not limited to one namespace.

It is used when:

- you want access across all namespaces
- you want access to cluster-level resources like `nodes` or `namespaces`

### Example (YAML)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-reader
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
```

### Real-world example

This is like a company-wide permission rather than department-only permission.

### My doubt (if any from chat)

You thought ClusterRole might mean permissions “outside the pod”.

### Clarification given

The correction was:

- not inside pod vs outside pod
- but **namespace scope vs cluster scope**

### Final understanding

ClusterRole means permissions across the cluster or for cluster-level resources.

---


## ROLE VS CLUSTER ROLE RESOURCES

Role / RoleBinding → Namespace scope.

ClusterRole / ClusterRoleBinding → Cluster scope.

## Namespaced resources[ROLE]

Examples:

pods,
services,
configmaps,
deployments.

## Cluster-level resources [CLUSTER ROLE]

Examples:

nodes,
namespaces,
persistentvolumes.


## 7. ClusterRoleBinding

### Definition

A **ClusterRoleBinding** attaches a ClusterRole to an identity.

### Detailed explanation (simple language)

Just like RoleBinding gives a Role to someone, ClusterRoleBinding gives a ClusterRole to someone.

This means the identity gets the wider permissions defined in the ClusterRole.

### Example (YAML)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: namespace-reader-binding
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: namespace-reader
```

### My doubt (if any from chat)

There was confusion about when to use ClusterRoleBinding instead of RoleBinding.

### Clarification given

Use ClusterRoleBinding when:

- the permissions must work across all namespaces
- or the target resource itself is cluster-scoped

### Final understanding

ClusterRoleBinding grants cluster-scope permissions to an identity.

---

## 8. Role vs ClusterRole

### Definition

This is the comparison between namespace-scoped and cluster-scoped permission definitions.

### Detailed explanation (simple language)

This was one of the most important clarifications in the conversation.

The correct way to think about it is:

```plaintext
Role → one namespace
ClusterRole → entire cluster or cluster resources
```

It is not about being inside a pod or outside a pod.

It is about the **scope of the resource and the permission**.

### Example (real-world)

- read pods in only `rbac-demo` namespace → Role
- read pods in all namespaces → ClusterRole
- read namespaces themselves → ClusterRole

### My doubt (if any from chat)

You asked if Role is for anything inside a pod and ClusterRoleBinding for anything outside the pod.

### Clarification given

That was corrected to:

```plaintext
Role / RoleBinding → namespace scope
ClusterRole / ClusterRoleBinding → cluster scope
```

### Final understanding

The difference is scope, not where the pod exists.

---

## 9. RoleBinding vs ClusterRoleBinding

### Definition

This is the comparison between namespaced permission assignment and cluster-wide permission assignment.

### Detailed explanation (simple language)

Even if two identities have similar rules, the binding type matters.

- RoleBinding attaches a namespaced Role
- ClusterRoleBinding attaches a ClusterRole

This changes how widely the permissions apply.

### Example

- RoleBinding can allow a ServiceAccount to list pods only in `rbac-demo`
- ClusterRoleBinding can allow that same ServiceAccount to list namespaces across the whole cluster

### My doubt (if any from chat)

You were learning how binding changes the behavior of access.

### Clarification given

The practical test with `kubectl auth can-i` showed the effect clearly.

### Final understanding

Bindings are what actually activate permissions for an identity.

---

## 10. How RBAC rules work: `apiGroups`, `resources`, `verbs`

### Definition

These fields define the actual permission rule inside a Role or ClusterRole.

Example:

```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

### Detailed explanation (simple language)

This was another key concept from the conversation.

A permission rule can be understood like this:

```plaintext
apiGroups → where the resource belongs
resources → what object
verbs     → what action is allowed
```

#### `apiGroups`
This tells Kubernetes which API section the resource belongs to.

Examples:

- `""` = core API group
- `apps` = apps API group
- `batch` = batch API group

#### `resources`
These are Kubernetes object types.

Examples:

- pods
- services
- deployments
- jobs
- configmaps

#### `verbs`
These are the allowed actions.

Examples:

- `get` = read one object
- `list` = list objects
- `watch` = watch changes
- `create` = create object
- `update` = modify object
- `delete` = remove object

### Example (YAML)

```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

Meaning:

- core API group
- only pods
- only read-style access

### Real-world example

Think of it like this:

- `apiGroups` = department
- `resources` = file type
- `verbs` = action allowed on file

### My doubt (if any from chat)

You asked what `apiGroups`, `resources`, and `verbs` mean.

### Clarification given

They were explained as:

- where
- what
- action

### Final understanding

These three fields together define the exact permission block.

---

## 11. `apiVersion` vs `apiGroup`

### Definition

`apiVersion` is not the same as `apiGroup`. The `apiGroup` is only one part of `apiVersion`.

### Detailed explanation (simple language)

This was an important correction in the conversation.

You asked whether the `apiGroup` value used in RBAC is the same as the value written in `apiVersion` while creating a pod.

The correct relation is:

```plaintext
apiVersion = apiGroup + version
```

Examples:

- `apiVersion: v1` → `apiGroup = ""` and `version = v1`
- `apiVersion: apps/v1` → `apiGroup = apps` and `version = v1`
- `apiVersion: batch/v1` → `apiGroup = batch` and `version = v1`

So RBAC uses the **apiGroup**, not the full `apiVersion` string.

### Example (YAML / real-world)

#### Pod

```yaml
apiVersion: v1
kind: Pod
```

RBAC:

```yaml
apiGroups: [""]
resources: ["pods"]
```

#### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
```

RBAC:

```yaml
apiGroups: ["apps"]
resources: ["deployments"]
```

### My doubt (if any from chat)

You asked if the value used in RBAC `apiGroups` is the same as `apiVersion`.

### Clarification given

No, not exactly.

`apiVersion` contains both the group and the version. RBAC only needs the group.

### Final understanding

RBAC uses `apiGroup`, not full `apiVersion`.

---

## 12. How to test permissions with `kubectl auth can-i`

### Definition

`kubectl auth can-i` is a command used to check whether an identity can perform a specific action.

### Detailed explanation (simple language)

This command is extremely useful for learning RBAC.

It lets you ask questions like:

- Can this ServiceAccount list pods?
- Can this user delete deployments?
- Can this identity read namespaces?

It does not create permissions. It only checks them.

### Example (commands)

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-demo:app-sa \
  -n rbac-demo
```

```bash
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-demo:app-sa \
  -n rbac-demo
```

### My doubt (if any from chat)

You were checking why some commands returned `yes` and some `no`.

### Clarification given

The results depend on:

- the identity used with `--as`
- the namespace
- the rules in Role/ClusterRole
- whether the correct Binding exists

### Final understanding

`kubectl auth can-i` is the best beginner tool to test RBAC rules.

---

## 13. Why `--as=app-sa` gave `no`, but full ServiceAccount name gave `yes`

### Definition

This topic explains how Kubernetes identifies ServiceAccounts during impersonation.

### Detailed explanation (simple language)

You ran:

```bash
kubectl auth can-i list pods --as=app-sa -n rbac-demo
```

That returned `no`.

Then you ran:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:rbac-demo:app-sa -n rbac-demo
```

That returned `yes`.

Why?

Because Kubernetes interprets them differently.

#### `--as=app-sa`
This is treated as a normal user named `app-sa`.

#### `--as=system:serviceaccount:rbac-demo:app-sa`
This is the real internal username format for a ServiceAccount.

### Example

ServiceAccount identity format:

```plaintext
system:serviceaccount:<namespace>:<serviceaccount-name>
```

### My doubt (if any from chat)

You asked what caused the difference.

### Clarification given

The first one impersonated a normal user string.
The second one impersonated the actual ServiceAccount identity.

### Final understanding

To test a ServiceAccount with `kubectl auth can-i`, use the full ServiceAccount username format.

---

## 14. User vs ServiceAccount

### Definition

This concept compares external users with Kubernetes-managed ServiceAccounts.

### Detailed explanation (simple language)

A ServiceAccount is an actual Kubernetes object.
A user is usually not.

That means:

- ServiceAccounts are created inside Kubernetes
- users usually come from outside Kubernetes through authentication methods

Kubernetes generally does not store human users as native API objects the same way it stores ServiceAccounts.

### Example (real-world)

- ServiceAccount = app identity created inside cluster
- User = human identity from certificate, OIDC, or some external system

### My doubt (if any from chat)

You asked how to make `--as=app-sa` work “by creating user”.

### Clarification given

Kubernetes does not really “create” users internally like ServiceAccounts.

But RBAC can still authorize a user name string if you create a Binding for a subject of kind `User`.

### Final understanding

ServiceAccount is a Kubernetes identity object. User is usually an externally authenticated identity.

---

## 15. How `--as=app-sa` can be made to work

### Definition

This concept explains impersonating a normal user string using RBAC.

### Detailed explanation (simple language)

Even if Kubernetes does not create users the same way it creates ServiceAccounts, you can still write a RoleBinding for a subject of kind `User`.

Then RBAC will evaluate permissions for that user name.

### Example (YAML)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: user-binding
  namespace: rbac-demo
subjects:
- kind: User
  name: app-sa
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Now this command can return `yes`:

```bash
kubectl auth can-i list pods --as=app-sa -n rbac-demo
```

### My doubt (if any from chat)

You asked how to make the short form work using user creation.

### Clarification given

The command works because RBAC is checking a `User` subject named `app-sa`, not because Kubernetes created a real internal user object.

### Final understanding

`--as=app-sa` can work if RBAC permissions are bound to a user subject with that exact name.

---

## 16. Real authentication methods in Kubernetes

### Definition

These are the actual ways identities authenticate to Kubernetes.

### Detailed explanation (simple language)

The conversation explained that Kubernetes supports multiple real authentication patterns.

### Types discussed

#### 1. ServiceAccount tokens
Used mainly by pods and in-cluster apps.

#### 2. Client certificates (x509)
Common for machines, system components, or lab-based user authentication.

#### 3. Bearer tokens
General token-based authentication. ServiceAccount tokens are a common example.

#### 4. OIDC / SSO
Modern production method for human users.

#### 5. Authenticating proxy
Advanced pattern used in some architectures.

### Example (real-world)

- Jenkins inside cluster → ServiceAccount
- kubelet or system component → certificate
- human engineer in production → OIDC/SSO

### My doubt (if any from chat)

You asked how to practice real authentication, not just RBAC authorization.

### Clarification given

A practical lab path was suggested:

- ServiceAccount lab
- certificate-based user auth lab
- token-based auth lab

### Final understanding

Authentication methods decide identity. RBAC decides permissions after that.

---

## 17. Certificate-based user authentication lab concept

### Definition

This concept explains how a user can authenticate using a certificate.

### Detailed explanation (simple language)

A certificate-based flow was described as a real way to simulate human user authentication.

The simplified flow is:

1. generate private key
2. generate CSR with CN as username
3. submit CSR to Kubernetes
4. approve CSR
5. extract signed certificate
6. add it to kubeconfig
7. use that user context
8. test access

Then RBAC can be granted to that user name.

### Example (conceptual command flow)

```bash
openssl genrsa -out app-user.key 2048
openssl req -new -key app-user.key -out app-user.csr -subj "/CN=app-user"
```

Then a Kubernetes CSR object is created and approved.

### My doubt (if any from chat)

You asked how to practice “real authentication”.

### Clarification given

Certificate-based login was given as a realistic lab for learning how human-style authentication works.

### Final understanding

Certificates can represent real user identity, and RBAC can then authorize that user.

---

## 18. Token-based authentication lab concept

### Definition

This concept explains how a token can represent an identity when calling the Kubernetes API.

### Detailed explanation (simple language)

A token can be used as proof of identity.

A common example is a ServiceAccount token.

When you create a token for a ServiceAccount, any client using that token talks to the API as that ServiceAccount.

### Example (command)

```bash
kubectl create token app-sa -n rbac-demo
```

This token can then be used with `curl` to call the API server.

### My doubt (if any from chat)

You wanted practical ways to learn authentication.

### Clarification given

Token-based practice was suggested as a way to understand how apps or Jenkins connect to the cluster.

### Final understanding

Token-based authentication is common for workloads and automation.

---

## 19. Practical RBAC lab created in the conversation

### Definition

This section summarizes the hands-on lab setup created in the conversation.

### Detailed explanation (simple language)

A full beginner lab was built using:

- namespace
- ServiceAccount
- Role
- RoleBinding
- Pod using the ServiceAccount
- ClusterRole
- ClusterRoleBinding
- `kubectl auth can-i` tests

### Example resources used

#### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-demo
```

#### ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: rbac-demo
```

#### Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-demo
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

#### RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: rbac-demo
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: rbac-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

### My doubt (if any from chat)

You asked for all steps and YAML files together.

### Clarification given

A complete step-by-step lab was provided, including tests and expected outputs.

### Final understanding

Hands-on practice with `kubectl auth can-i` is the best way to build RBAC understanding.

---

## 20. Important namespace vs cluster scope clarification

### Definition

This concept explains the scope rule that should be remembered while choosing Role or ClusterRole.

### Detailed explanation (simple language)

This became one of the main final clarifications.

The correct mental model is:

```plaintext
If resource is inside one namespace → Role may be enough
If access is needed across cluster or resource is cluster-scoped → ClusterRole needed
```

Examples:

- `pods` are namespaced
- `namespaces` are cluster-scoped
- `nodes` are cluster-scoped

### Example (real-world)

- read pods only in `rbac-demo` → Role
- read pods in all namespaces → ClusterRole
- read namespaces → ClusterRole

### My doubt (if any from chat)

You asked if Role is for anything “inside pod” and ClusterRoleBinding for anything “outside pod”.

### Clarification given

That was corrected to namespace scope versus cluster scope.

### Final understanding

Always think in terms of scope, not pod internals.

---

## 21. Best practices discussed in the conversation

### 1. Use custom ServiceAccounts
Do not rely on the default ServiceAccount for real workloads unless there is a specific reason.

### 2. Follow least privilege
Give only the permissions required.

Examples:

- read pods only if reading pods is needed
- do not allow delete unless necessary
- avoid broad cluster-wide access unless truly required

### 3. Practice with `kubectl auth can-i`
This is one of the safest and best ways to learn and verify RBAC.

### 4. Understand scope before writing RBAC
Before creating Role or ClusterRole, ask:

- is the resource namespaced?
- do I need access in one namespace or across the cluster?

### 5. Use Role for namespaced access when possible
Prefer narrower permissions before jumping to ClusterRole.

### 6. Create dedicated ServiceAccounts for workloads
For example:

- Jenkins SA
- app SA
- controller SA

This keeps permissions isolated and easier to manage.

### 7. Separate authentication from authorization in your mind
A lot of confusion disappears once you clearly think:

- authentication = identity
- authorization = permissions

---

## 22. Final structured summary

### Core model

```plaintext
Authentication → Who are you?
Authorization  → What can you do?
```

### Identity objects and forms

- ServiceAccount = Kubernetes-managed identity for pods/apps
- User = usually external identity

### Permission definitions

- Role = namespaced permissions
- ClusterRole = cluster-wide or cluster-resource permissions

### Permission assignment

- RoleBinding = attaches Role to identity
- ClusterRoleBinding = attaches ClusterRole to identity

### RBAC rule fields

```plaintext
apiGroups → where resource belongs
resources → what resource
verbs     → what action allowed
```

### Scope rule to remember

```plaintext
Role / RoleBinding → one namespace
ClusterRole / ClusterRoleBinding → cluster scope
```

### ServiceAccount impersonation rule

```plaintext
system:serviceaccount:<namespace>:<serviceaccount-name>
```

### Most important beginner memory line

```plaintext
ServiceAccount = who
Role / ClusterRole = what allowed
Binding = connects both
```

---

## 23. Final conclusions and key takeaways

1. RBAC is Kubernetes authorization.
2. Authentication and authorization are separate steps.
3. ServiceAccounts are identities for pods and workloads.
4. Roles define namespaced permissions.
5. RoleBindings attach Roles to identities.
6. ClusterRoles define cluster-wide or cluster-resource permissions.
7. ClusterRoleBindings attach ClusterRoles to identities.
8. Role vs ClusterRole is about scope, not inside-pod vs outside-pod.
9. RBAC rules are built using `apiGroups`, `resources`, and `verbs`.
10. `apiVersion` is not the same as `apiGroup`; RBAC uses only the API group.
11. `kubectl auth can-i` is the best way to practice RBAC safely.
12. `--as=app-sa` means user named `app-sa`, not a ServiceAccount.
13. Real ServiceAccount impersonation uses `system:serviceaccount:<namespace>:<name>`.
14. Users usually come from external authentication systems, not as native Kubernetes objects.
15. Least privilege and custom ServiceAccounts are important production practices.

---

## 24. Quick revision cheat sheet

```plaintext
ServiceAccount → identity for pod/app
User           → usually external human identity

Role           → permissions in one namespace
RoleBinding    → attach Role to identity

ClusterRole    → permissions across cluster or cluster resources
ClusterRoleBinding → attach ClusterRole to identity

apiGroups      → API section
resources      → object type
verbs          → action

Authentication → who are you?
Authorization  → what can you do?
```

---

## 25. Suggested next practice

To strengthen this topic further, the next useful labs would be:

1. create a Role with `create`, `get`, and `list` for pods
2. bind it to a second ServiceAccount
3. compare permissions using `kubectl auth can-i`
4. create a ClusterRole for reading namespaces and test the difference
5. practice one certificate-based user authentication lab
6. practice one token-based API call using a ServiceAccount token

These exercises will make the differences between identity, authentication, and authorization very clear.
