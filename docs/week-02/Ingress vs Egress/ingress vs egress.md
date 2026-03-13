1️⃣ Ingress Rule (Traffic Coming Into a Pod)

Example:

endpointSelector:
  matchLabels:
    app: backend

ingress:
- fromEndpoints:
  - matchLabels:
      app: frontend
Meaning
Part	What it means
endpointSelector	Destination pod (backend)
fromEndpoints	Source pod (frontend)

So the flow becomes:

frontend pod  ─────► backend pod
        (source)       (destination)

✔ Allowed

But:

random pod ─────► backend pod

❌ Blocked

So for ingress:

endpointSelector → destination
fromEndpoints → source
2️⃣ Egress Rule (Traffic Going Out of a Pod)

Example:

endpointSelector:
  matchLabels:
    app: backend

egress:
- toEndpoints:
  - matchLabels:
      app: database
Meaning
Part	What it means
endpointSelector	Source pod (backend)
toEndpoints	Destination pod (database)

Flow:

backend pod ─────► database pod
      (source)        (destination)

✔ Allowed

3️⃣ Quick Comparison
Rule Type	endpointSelector	Other field
Ingress	Destination pod	fromEndpoints = Source
Egress	Source pod	toEndpoints = Destination
4️⃣ Easy Way to Remember
Ingress
Someone → My Pod

So the policy is on the destination pod.

endpointSelector = my pod
fromEndpoints = who can access me
Egress
My Pod → Someone

So the policy is on the source pod.

endpointSelector = my pod
toEndpoints = where I can go
5️⃣ Visual Summary
INGRESS
frontend ─────► backend
 source         destination
fromEndpoints   endpointSelector
EGRESS
backend ─────► database
 source         destination
endpointSelector  toEndpoints

✅ Short rule

Ingress  → controls incoming traffic
Egress   → controls outgoing traffic