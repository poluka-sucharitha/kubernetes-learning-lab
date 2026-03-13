Cilium Network Policy Assignment: 
==================================
- Implement Cilium Network Policies to control traffic at multiple layers:
- L3 (IP/CIDR) – Allow and deny traffic based on source/destination IPs.
- L4 (Port/Protocol) – Allow and deny traffic for specific ports and protocols.
- L7 (Application Layer) – Allow and deny traffic to specific namespaces or services.
- Restrict access so only a specific pod in a deployment can communicate with others.
- Egress control – Allow access to github.com and deny access to google.com.
- Hubble visualization for each of these task
