# Kubernetes Health Checks: Liveness Probe & Readiness Probe

## Overview

Kubernetes provides **health checks** to monitor containers running inside Pods.  
These checks help Kubernetes determine:

- Whether a container is **alive**
- Whether a container is **ready to serve traffic**

The two main probes used are:

1. **Liveness Probe**
2. **Readiness Probe**

These probes are executed by the **kubelet** running on each worker node.

---

# 1. Liveness Probe

## Definition

A **Liveness Probe** checks whether the **container is still alive and functioning**.

If the probe fails continuously based on the configured threshold, Kubernetes **restarts the container**.

## Purpose

Detect situations where the application is:

- Stuck in a **deadlock**
- Hung in an **infinite loop**
- Not responding internally

## Behavior


Liveness probe fails
↓
Kubelet detects failure
↓
Container is restarted


## Example YAML

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
Key Points

Checks if the application process is alive

If it fails → container restart

Does not control traffic routing

2. Readiness Probe
Definition

A Readiness Probe checks whether the container is ready to serve traffic.

If the probe fails, Kubernetes removes the Pod from the Service endpoints, so traffic will not be routed to that Pod.

The container continues running.

Purpose

Ensure traffic is only sent when the application is fully ready.

Typical checks include:

Database connection

Cache availability

External service dependencies

Configuration loading

Behavior
Readiness probe fails
        ↓
Pod removed from Service endpoints
        ↓
Traffic stops going to that Pod
Example YAML
readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
Key Points

Controls traffic routing

Pod remains running

Only removed from Service endpoints

3. Difference Between Liveness and Readiness
Feature	Liveness Probe	Readiness Probe
Purpose	Check if container is alive	Check if container is ready
Failure Action	Restart container	Remove pod from service endpoints
Traffic Impact	Container restarted	Pod stops receiving traffic
Dependency Check	Usually basic health	Often checks dependencies
4. Who Performs the Health Checks

Health checks are performed by the kubelet.

Architecture
Control Plane
      │
      ▼
Scheduler assigns Pod to Node
      │
      ▼
Worker Node
   │
   │
Kubelet performs probes
   │
   ▼
Container inside Pod

The kubelet periodically sends health check requests to the container.

5. Types of Probes

Kubernetes supports three probe methods.

1. HTTP Probe

Checks an HTTP endpoint.

Example:

livenessProbe:
  httpGet:
    path: /health
    port: 8080

Kubelet sends:

GET http://pod-ip:8080/health
2. TCP Probe

Checks whether a TCP port is open.

Example:

livenessProbe:
  tcpSocket:
    port: 3306

Used for services like:

MySQL

Redis

3. Exec Probe

Runs a command inside the container.

Example:

livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy

If the command fails, the probe fails.

6. Probe Configuration Parameters
Parameter	Description
initialDelaySeconds	Time to wait before first probe
periodSeconds	Frequency of probe
timeoutSeconds	Probe timeout
failureThreshold	Number of failures before action
successThreshold	Success count required

Example:

periodSeconds: 10
failureThreshold: 3

Meaning:

Check every 10 seconds
Restart container after 3 failures
7. Typical Health Endpoints in Production

Most applications expose different endpoints for probes.

Example:

/livez   → Liveness check
/readyz  → Readiness check

Example configuration:

livenessProbe:
  httpGet:
    path: /livez
    port: 8080

readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
8. Real Production Flow
Pod starts
     ↓
Application initializing
     ↓
Readiness probe fails
     ↓
Pod not added to Service
     ↓
Application ready
     ↓
Readiness probe succeeds
     ↓
Pod added to Service endpoints
     ↓
Traffic begins
9. Important Best Practices

✔ Use different endpoints for liveness and readiness probes.

✔ Liveness should check basic application health only.

✔ Readiness should check application dependencies.

✔ Avoid making liveness checks dependent on external services.

✔ Configure proper delays for applications that take time to start.

10. Simple Concept Summary
Liveness Probe
→ Is the container alive?
→ If it fails → restart container

Readiness Probe
→ Is the container ready to serve traffic?
→ If it fails → stop sending traffic
11. Visual Summary
                Container
                    │
       ┌────────────┴────────────┐
       │                         │
   Liveness Probe           Readiness Probe
   (Container alive?)       (Ready for traffic?)
       │                         │
   Fail → Restart           Fail → Remove from service
12. Quick Interview Answer

What is a Liveness Probe?

A liveness probe checks if a container is alive. If it fails repeatedly, Kubernetes restarts the container.

What is a Readiness Probe?

A readiness probe checks if a container is ready to serve traffic. If it fails, the pod is removed from the service endpoints so it stops receiving traffic.