# Kubernetes Networking & Cilium Notes

## 1. Kubernetes Basic Architecture

In Kubernetes, applications usually run as pods.

A typical microservice architecture looks like this:

```
Internet
   ↓
Frontend Pod
   ↓
Backend Pod
   ↓
Database Pod
```

Pods communicate with each other using Pod IPs or Services.

## 2. Deployment

A Deployment is a Kubernetes object used to manage pods.

Example:

```bash
kubectl create deployment frontend --image=nginx --replicas=2 -n demo
```

This means:

- Deployment: frontend
- Replicas: 2

Kubernetes will create:

- frontend-xxxxx
- frontend-yyyyy

So:

Deployment → manages ReplicaSet → manages Pods

## 3. Replicas vs Pods

| Term      | Meaning                                      |
|-----------|----------------------------------------------|
| Pod       | Smallest unit in Kubernetes that runs containers |
| Replicas  | Number of pod copies Kubernetes should maintain |

Example:

```yaml
replicas: 2
```

Kubernetes ensures 2 pods are always running.

If one pod dies, another one will be created automatically.

## 4. Labels in Kubernetes

Labels are key-value metadata attached to Kubernetes objects.

Example:

```bash
kubectl label deploy/frontend app=frontend -n demo
```

Now the deployment has:

```yaml
app=frontend
```

Pods created by this deployment will also inherit this label.

Example:

```yaml
frontend-abcde
labels:
  app=frontend
```

Labels are used for:

- Services
- Network Policies
- Monitoring
- Pod selection

## 5. Services

Pods are ephemeral (they change IP).

Therefore Kubernetes provides Services.

A Service provides a stable IP and DNS name.

Example:

```bash
kubectl expose deployment frontend --port=80 --name=frontend-svc -n demo
```

This creates:

- Service Name: frontend-svc
- ClusterIP: 10.96.x.x
- Port: 80

Pods behind the service become service endpoints.

Creating service using kubectl create

Example:

```bash
kubectl create service clusterip frontend-svc --tcp=80:80 -n demo
```

## 6. Service DNS

Kubernetes automatically creates DNS records.

Example:

```
backend-svc.demo.svc.cluster.local
```

Inside the same namespace you can use:

```
http://backend-svc
```

DNS resolution is handled by CoreDNS.

## 7. CoreDNS

CoreDNS is the DNS server running in Kubernetes.

Check:

```bash
kubectl get pods -n kube-system | grep coredns
```

Pods use:

```
/etc/resolv.conf
```

Example:

```
nameserver 10.96.0.10
```

This is the kube-dns service IP.

## 8. Testing Pod Connectivity

You can test communication between pods using:

```bash
kubectl exec
```

Example:

```bash
kubectl exec -it frontend-pod -n demo -- sh
```

Inside the pod:

```bash
wget http://backend-svc
```

If working:

```
Welcome to nginx!
```

## 9. kubectl exec Syntax

Correct syntax:

```bash
kubectl exec -it <pod-name> -n <namespace> -- sh
```

Example:

```bash
kubectl exec -it frontend-abc123 -n demo -- sh
```

Important:

- `--` is required

## 10. Installing wget inside container

Inside Debian-based containers:

```bash
apt update
apt install wget -y
```

Test:

```bash
wget -O- http://backend-svc
```

## 11. Kubernetes Network Policies

Network policies control pod-to-pod traffic.

There are two directions:

- Ingress
- Egress

## 12. Ingress vs Egress

| Policy  | Meaning                          |
|---------|----------------------------------|
| Ingress | Controls incoming traffic to a pod |
| Egress  | Controls outgoing traffic from a pod |

Example:

frontend → backend

From backend perspective:

- Ingress

From frontend perspective:

- Egress

## 13. Ingress Policy Example

Allow only frontend to reach backend.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
```

Result:

- frontend → backend ✔
- others → backend ❌

## 14. Egress Policy Example

Allow backend to reach database.

```yaml
endpointSelector:
  matchLabels:
    app: backend
egress:
- toEndpoints:
  - matchLabels:
      app: database
```

Result:

- backend → database ✔
- backend → other pods ❌

## 15. EgressDeny

Explicitly block outgoing traffic.

Example:

```yaml
endpointSelector:
  matchLabels:
    app: frontend
egressDeny:
- toEndpoints:
  - matchLabels:
      app: backend
```

Result:

- frontend → backend ❌
- frontend → others ✔

## 16. Difference Between Egress and EgressDeny

| Policy     | Behavior                          |
|------------|-----------------------------------|
| egress     | allow only specified destinations |
| egressDeny | block only specified destinations |

Example:

egress:
- frontend → backend ✔
- frontend → others ❌

egressDeny:
- frontend → backend ❌
- frontend → others ✔

## 17. DNS Traffic

When a pod runs:

```bash
wget http://backend-svc
```

First step:

DNS lookup

Traffic:

pod → kube-dns :53

Ports used:

- UDP 53
- TCP 53

If DNS is blocked:

```
Temporary failure in name resolution
```

## 18. Allowing DNS in Network Policies

Example rule:

```yaml
egress:
- toEndpoints:
  - matchLabels:
      k8s:io.kubernetes.pod.namespace: kube-system
      k8s:k8s-app: kube-dns
  toPorts:
  - ports:
    - port: "53"
      protocol: UDP
    - port: "53"
      protocol: TCP
```

## 19. Production Security Model

Typical production architecture:

```
Internet
   ↓
Frontend
   ↓
Backend
   ↓
Database
```

Security rules:

- Internet → frontend ✔
- Internet → backend ❌
- frontend → backend ✔
- backend → database ✔
- frontend → database ❌

## 20. Traffic Enforcement

Policies enforce:

- backend ingress → only frontend allowed
- database ingress → only backend allowed
- backend egress → only database allowed
- frontend egress → backend only

## 21. Traffic Flow Diagram

```
           Ingress
     (incoming traffic)
           ↓
        ┌─────┐
        │ POD │
        └─────┘
           ↑
           Egress
     (outgoing traffic)
```

## 22. Quick Memory Trick

- Ingress = Incoming traffic
- Egress = Exiting traffic

or

- Ingress protects the destination pod
- Egress controls where a pod can go

## 23. Final Example Flow

- Internet → frontend ✔
- frontend → backend ✔
- backend → database ✔

Blocked:

- Internet → backend ❌
- frontend → database ❌

## 24. Key Takeaways

- Deployment manages pods
- Labels identify workloads
- Services provide stable access
- CoreDNS resolves service names
- Network policies control pod traffic
- Ingress controls incoming traffic
- Egress controls outgoing traffic
- egressDeny blocks specific outgoing traffic