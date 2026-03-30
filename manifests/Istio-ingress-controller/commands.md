# MetalLB should already exist in your setup
kubectl apply -f 01-metallb-pool.yaml

# Istio control plane
istioctl install --set profile=minimal -y

# Istio ingress namespace + gateway deployment
kubectl apply -f 00-istio-ingress-namespace.yaml
kubectl apply -f 01-istio-ingressgateway.yaml

# App namespace with injection enabled
kubectl apply -f 02-shop-namespace.yaml

# App resources
kubectl apply -f 03-app-configmap.yaml
kubectl apply -f 04-rbac-orders.yaml
kubectl apply -f 05-pv-pvc.yaml
kubectl apply -f 06-orders-deployment.yaml
kubectl apply -f 07-orders-service.yaml
kubectl apply -f 08-frontend-deployment.yaml
kubectl apply -f 09-frontend-service.yaml
kubectl apply -f 10-hpa-frontend.yaml
kubectl apply -f 11-keda-orders-scaledobject.yaml

# Network policies
kubectl apply -f 14-networkpolicy-default-deny.yaml
kubectl apply -f 15-cilium-allow-istio-ingressgateway-to-frontend.yaml
kubectl apply -f 16-cilium-allow-frontend-to-orders.yaml

# Istio traffic resources
kubectl apply -f 12-shop-gateway.yaml
kubectl apply -f 13-shop-virtualservice.yaml


kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
kubectl get svc -n istio-ingress
kubectl get pods -n shop
kubectl get gateway,virtualservice -n shop
kubectl get hpa -n shop
kubectl get scaledobject -n shop


kubectl get pods -n shop
kubectl describe pod -n shop <frontend-pod-name>
kubectl describe pod -n shop <orders-pod-name>

Test from external IP
---------------------
kubectl get svc istio-ingressgateway -n istio-ingress
curl -H "Host: shop.local" http://<EXTERNAL-IP>/
curl -H "Host: shop.local" http://<EXTERNAL-IP>/orders

Test RBAC
---------
kubectl auth can-i get configmaps --as=system:serviceaccount:shop:orders-sa -n shop
kubectl auth can-i delete configmaps --as=system:serviceaccount:shop:orders-sa -n shop

Test PVC
--------
kubectl exec -it deploy/orders -n shop -- sh
echo "hello from pvc" > /data/test.txt
cat /data/test.txt

Test HPA:
--------
kubectl run loadgen --rm -it --image=busybox -n shop -- sh
while true; do wget -q -O- http://frontend.shop.svc.cluster.local; done

kubectl get hpa -n shop -w
kubectl get pods -n shop -w

Test KEDA:
----------
kubectl exec -it deploy/orders -n shop -- sh
while true; do :; done

kubectl get scaledobject -n shop
kubectl get hpa -n shop
kubectl get pods -n shop -w

With nginx-ingress, your flow was:
==================================
Client -> MetalLB external IP -> ingress-nginx controller -> Ingress rules -> Service -> Pod

With Istio, it becomes::
========================
Client -> MetalLB external IP -> Istio ingress gateway -> Gateway + VirtualService -> Service -> Pod

commands to install istio gateway:
===================================
curl -L https://istio.io/downloadIstio | sh -    ===> command for installing istioctl
istioctl install -y
kubectl get pods -n istio-system
kubectl get svc -n istio-system