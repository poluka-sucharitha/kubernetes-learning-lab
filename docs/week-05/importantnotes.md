* First, we install the controller (like Istio, Kong, or Envoy Gateway) using Helm.
* During installation, it also installs the required Gateway API CRDs into the cluster.
* These CRDs define resources like Gateway, HTTPRoute, and other routing objects.
* Once installed, the controller watches these resources and processes them.
* We then create Gateway and routing configurations (like HTTPRoute or VirtualService).
* The controller reads these configurations and sets up the routing accordingly inside the cluster.