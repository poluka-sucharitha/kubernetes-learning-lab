# Cilium Network Policy Practice

## Introduction
This document provides best practices for implementing Cilium Network Policies in Kubernetes environments.

## Table of Contents
1. [Overview of Cilium](#overview-of-cilium)
2. [Creating Network Policies](#creating-network-policies)
3. [Best Practices](#best-practices)
4. [Examples](#examples)

## Overview of Cilium
Cilium is an open-source project that provides networking, security, and load balancing capabilities for containerized applications.

## Creating Network Policies
To create a Cilium Network Policy, you need to define the policy in a YAML file:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: demo-network-policy
spec:
  endpointSelector:
    matchLabels:
      app: demo-app
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: other-app
```

## Best Practices
- **Label Your Pods**: Always label your pods to make selecting endpoints easier.
- **Limit the Scope**: Limit access where possible, specifying only the endpoints necessary for communication.
- **Monitor Policies**: Regularly review and monitor your network policies for effectiveness.

## Examples
### Example 1: Allow traffic from a specific pod
To allow traffic from a pod labeled `app=frontend`, use the following specification:

```yaml
spec:
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
```

### Example 2: Deny all traffic by default
You can also create a default deny policy by not specifying any ingress rules:

```yaml
spec:
  ingress:
  - toEndpoints:
    - matchLabels:
        app: allow-me
```

## Conclusion
Implementing effective Cilium Network Policies enhances the security and stability of your Kubernetes applications.
