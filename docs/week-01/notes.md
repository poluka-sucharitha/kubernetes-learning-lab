Week 01 — Kubernetes Fundamentals and Cluster Setup

Environment Setup:
-----------------
The following tools were installed and used for this Kubernetes lab environment.
-------------------------------
| Tool             | Version  |
|------------------|----------|
| kubectl          | v1.34.1  |
| kind             | v0.31.0  |
| helm             | v4.1.1   |
| terraform        | v1.10.5  |
| k9s              | v0.50.18 |
| ZSH              | v5.8.1   |
| powerlevel10k    | v10      |

These tools help in managing Kubernetes clusters, deployments, and infrastructure automation.



Kubernetes Advantages:
======================

Kubernetes provides several key capabilities that make it ideal for container orchestration.

Scalability- Kubernetes allows applications to scale horizontally by increasing or decreasing the number of running pods.

Resilience - If a pod fails, Kubernetes automatically recreates it and maintains the desired number of replicas.

Rolling Updates - Kubernetes enables updating applications without downtime by gradually replacing old pods with new ones.



Kubernetes Control Plane Components:
====================================

The control plane manages the overall cluster state.
-------------------------------------------------------------------------
| Component                | Responsibility                             |
|--------------------------|--------------------------------------------|
| kube-apiserver           | Entry point for all cluster communication  |
| etcd                     | Stores cluster state and configuration     |
| kube-scheduler           | Assigns pods to nodes                      |
| kube-controller-manager  | Maintains desired cluster state            |



Container Runtime in Kubernetes:
================================
Kubernetes runs containers using container runtimes such as:
- containerd
- CRI-O

These runtimes rely on Linux kernel features such as:
- Namespaces → isolation
- Cgroups → resource control
- Union Filesystems → layered container images



Liveness vs Readiness Probes[for ensuring Resilience]
===========================
Liveness Probe
Checks whether a container is alive.  
If the probe fails repeatedly, Kubernetes restarts the container.

Readiness Probe
Checks whether a container is ready to receive traffic.  
If it fails, the pod will be removed from service endpoints.



Pod Anti-Affinity:
==================
Pod Anti-Affinity ensures that similar pods do **not run on the same node**.
This improves availability and fault tolerance by distributing workloads across multiple nodes.



Kind Cluster Architecture (Local Setup):
=======================================
The cluster environment is created using Kind (Kubernetes in Docker)

Windows Host
↓
WSL2 (Linux Kernel)
↓
Docker
↓
Kind Control Plane Container
↓
Kubernetes Cluster Nodes


Kubernetes Cluster Creation Tool Options
========================================
| Tool              | Description                              |
|-------------------|------------------------------------------|
| kubeadm           | Manual Kubernetes cluster setup          |
| kind              | Kubernetes cluster running inside Docker |
| minikube          | Local single node cluster                |
| EKS               | Managed Kubernetes in AWS                |
| AKS               | Managed Kubernetes in Azure              |
| GKE               | Managed Kubernetes in Google Cloud       |




Kubernetes Cluster Creation Tool Options:
--------------------------------------------------------
| Tool      | Description                              |
|-----------|------------------------------------------|
| kubeadm   | Manual Kubernetes cluster setup          |
| kind      | Kubernetes cluster running inside Docker |
| minikube  | Local single node cluster                |
| EKS       | Managed Kubernetes in AWS                |
| AKS       | Managed Kubernetes in Azure              |
| GKE       | Managed Kubernetes in Google Cloud       |



Kubernetes Manifest Files:
==========================
A Kubernetes manifest file is a YAML or JSON file that defines the desired state of Kubernetes resources.

Examples of resources defined using manifests:
- Pods
- Deployments
- Services
- ConfigMaps
- Secrets
- Ingress

These files are applied using- kubectl apply -f manifest.yaml

Pod IP vs Service IP [for assigning Ip's for cluster]:
=====================
----------------------------------------------------------
| Pod IP                     | Service IP                 |
|----------------------------|----------------------------|
| Real IP assigned by CNI    | Virtual IP                 |
| Changes when pod restarts  | Stable                     |
| Used for pod communication | Used for service discovery |

---


Note:
=====
Control plane components run as **static pods**.
Default path for control plane components manifest file: /etc/kubernetes/manifests
Files located here automatically start control plane components such as:
- kube-apiserver
- kube-scheduler
- kube-controller-manager
- etcd

CoreDNS:
========

CoreDNS is the DNS server used inside Kubernetes clusters for service discovery.
It allows pods to communicate with services using DNS names instead of IP addresses.

Example:
If a service named `frontend` exists in namespace `default`,
pods can access it using:

frontend.default.svc.cluster.local

CoreDNS automatically resolves this DNS name to the Service ClusterIP.

CoreDNS runs as a Deployment in the `kube-system` namespace.

Command to check CoreDNS pods:

kubectl get pods -n kube-system | grep coredns


CoreDNS Responsibilities
-----------------------
| Function              | Description |
|-----------------------|-------------|
| Service Discovery     | Resolves service names to ClusterIP |
| Internal DNS          | Provides DNS inside the cluster |
| Pod Communication     | Allows pods to reach services by name |
| DNS Forwarding        | Forwards external DNS queries to upstream DNS servers |


Example Flow
------------

Pod → DNS Query → CoreDNS → Service IP → kube-proxy → Pod

