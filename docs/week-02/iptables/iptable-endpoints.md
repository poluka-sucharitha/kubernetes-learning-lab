# Kubernetes Service → Endpoints → iptables (kube-proxy) Lab

## Objective

Understand how **Kubernetes Services route traffic to Pods** using **kube-proxy and iptables**.

This lab demonstrates:

- How a **Service forwards traffic to Pods**
- How **Endpoints are created**
- How **kube-proxy updates iptables rules**
- How traffic automatically updates when **Pods change**

---

# Lab Environment

Cluster created using **kind**.

Check the cluster:

```bash
kind get clusters
kubectl get nodes

Example output:

NAME                         STATUS   ROLES           AGE
iptables-lab-control-plane   Ready    control-plane   5m
Step 1 — Create Deployment

Create an nginx deployment with 2 replicas.

kubectl create deployment nginx-demo --image=nginx --replicas=2

Check the pods:

kubectl get pods -o wide

Example output:

NAME                        READY   STATUS    IP
nginx-demo-xxxxx            1/1     Running   10.244.0.12
nginx-demo-yyyyy            1/1     Running   10.244.0.13

These Pod IPs become Service Endpoints.

Step 2 — Create Service

Expose the deployment as a ClusterIP service.

kubectl expose deployment nginx-demo --port=80

Check the service:

kubectl get svc

Example output:

NAME         TYPE        CLUSTER-IP
nginx-demo   ClusterIP   10.96.239.59

The Service now routes traffic to the nginx pods.

Step 3 — Observe iptables Rules

Enter the kind control-plane node container:

docker exec -it iptables-lab-control-plane sh

Check iptables rules:

iptables -t nat -L | grep KUBE-SEP

Example output:

/* default/nginx-demo -> 10.244.0.12:80 */
statistic mode random probability 0.50000000000

/* default/nginx-demo -> 10.244.0.13:80 */
Meaning

Service nginx-demo forwards traffic to two backend pods.

Service
   ↓
10.244.0.12:80
10.244.0.13:80

The probability rule performs load balancing.

50% → Pod1
50% → Pod2
Step 4 — Delete Pods

Delete all pods:

kubectl delete pods -l app=nginx-demo

The Deployment controller automatically recreates new pods.

Check pods again:

kubectl get pods -o wide

Example:

NAME                        READY   STATUS    IP
nginx-demo-aaaaa            1/1     Running   10.244.0.14
nginx-demo-bbbbb            1/1     Running   10.244.0.15

Pod IPs changed.

Step 5 — Observe iptables Update

Check iptables rules again:

iptables -t nat -L | grep KUBE-SEP

Example output:

/* default/nginx-demo -> 10.244.0.14:80 */
statistic mode random probability 0.50000000000

/* default/nginx-demo -> 10.244.0.15:80 */

Old pod IPs were automatically removed.

What Happened Internally

When pods change, Kubernetes automatically updates networking.

Pod Created / Deleted
        ↓
Endpoint Controller updates Endpoints
        ↓
API Server updated
        ↓
kube-proxy detects change
        ↓
kube-proxy rewrites iptables rules
Actual Traffic Flow

Packet routing inside the cluster:

Client Pod
   ↓
Service IP
   ↓
iptables rule match
   ↓
DNAT rewrite
   ↓
Backend Pod IP

Example:

Before iptables rewrite:

SRC: pod-ip
DST: service-ip

After iptables rewrite:

SRC: pod-ip
DST: backend-pod-ip

This is called DNAT (Destination NAT).

iptables Chain Flow

Actual packet traversal:

Client
  ↓
KUBE-SERVICES
  ↓
KUBE-SVC-XXXX
  ↓
Load balancing rule
  ↓
KUBE-SEP-XXXX
  ↓
Pod IP
Why Random Probability Appears

Example rule:

statistic mode random probability 0.50000000000

Meaning:

50% traffic → Pod A
50% traffic → Pod B

This is iptables-based load balancing.

Production Scenario Simulated

This lab simulates a real production situation.

Pod crash
   ↓
Endpoint removed
   ↓
kube-proxy updates iptables
   ↓
Traffic redirected to healthy pods

Users do not experience downtime.

This demonstrates Kubernetes self-healing networking.

Useful Debug Commands

Check endpoints:

kubectl get endpoints nginx-demo

Check EndpointSlices:

kubectl get endpointslices

Check kube-proxy logs:

kubectl logs -n kube-system -l k8s-app=kube-proxy

Check service iptables rules:

iptables-save | grep nginx-demo
Important Production Insight

iptables works well for small clusters.

Large clusters may have:

10,000 services
50,000 pods

iptables rules become very large.

Many organizations now use Cilium instead of kube-proxy.

Instead of iptables:

Service
   ↓
eBPF map lookup
   ↓
Pod

This provides faster networking.

Kubernetes Debugging Commands
Create Deployment
kubectl create deployment nginx-demo --image=nginx --replicas=2

Architecture:

Deployment
   ↓
ReplicaSet
   ↓
Pods

Used for stateless applications.

Examples:

Web servers

APIs

Microservices

kubectl run

Create a temporary debug pod.

kubectl run test --image=busybox -it --rm -- sh

Flow:

kubectl run
     ↓
Creates temporary pod
     ↓
Opens shell
     ↓
Pod deleted when exiting

Use cases:

Debug networking

Test service connectivity

DNS testing

Examples:

wget nginx-demo
ping pod-ip
nslookup service-name
kubectl exec

Run commands inside an existing pod.

kubectl exec -it <pod-name> -- sh

Example:

kubectl exec -it nginx-demo-abc123 -- sh

Use cases:

Debug applications

Inspect container filesystem

Run diagnostic commands

HTTP Testing with wget

Send HTTP request to service:

wget -qO- nginx-demo

Explanation:

Option	Meaning
wget	HTTP client
-q	quiet mode
-O-	print output to terminal

Traffic flow:

Client Pod
   ↓
Service IP
   ↓
kube-proxy (iptables)
   ↓
Backend Pod
Network Testing with ping

Check connectivity between pods.

ping 10.244.0.5

Used to test:

Pod-to-pod networking

CNI functionality

Basic connectivity

Flow:

Pod A
   ↓
CNI network
   ↓
Pod B
Typical Kubernetes Debug Flow
kubectl run test --image=busybox -it --rm -- sh
        ↓
Inside debug pod
        ↓
ping pod-ip
wget service-name
        ↓
Verify networking and service routing
Quick Command Summary
Command	Purpose
kubectl create deployment	Create application workload
kubectl run	Create temporary debug pod
kubectl exec	Run commands inside running container
wget	Test HTTP connectivity
ping	Test network connectivity