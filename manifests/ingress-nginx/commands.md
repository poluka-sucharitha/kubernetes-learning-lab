kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-metallb-pool.yaml
kubectl apply -f 02-app-configmap.yaml
kubectl apply -f 03-rbac-orders.yaml
kubectl apply -f 04-pv-pvc.yaml
kubectl apply -f 05-orders-deployment.yaml
kubectl apply -f 06-orders-service.yaml
kubectl apply -f 07-frontend-deployment.yaml
kubectl apply -f 08-frontend-service.yaml
kubectl apply -f 09-ingress.yaml
kubectl apply -f 10-networkpolicy-default-deny.yaml
kubectl apply -f 11-cilium-allow-ingress-to-frontend.yaml
kubectl apply -f 12-cilium-allow-frontend-to-orders.yaml
kubectl apply -f 13-hpa-frontend.yaml
kubectl apply -f 14-keda-orders-scaledobject.yaml


kubectl get all -n shop
kubectl get pvc -n shop
kubectl get ingress -n shop
kubectl get svc -n ingress-nginx
kubectl get scaledobject -n shop
kubectl get hpa -n shop
kubectl get svc -n ingress-nginx

Test ingress:
kubectl get svc ingress-nginx-controller -n ingress-nginx  -->Get the external IP:
curl -H "Host: shop.local" http://<EXTERNAL-IP>/
curl -H "Host: shop.local" http://<EXTERNAL-IP>/api/orders
curl -H "Host: shop.local" http://<EXTERNAL-IP>/
curl -H "Host: shop.local" http://<EXTERNAL-IP>/api/orders

Test RBAC:
kubectl auth can-i get configmaps --as=system:serviceaccount:shop:orders-sa -n shop
kubectl auth can-i delete configmaps --as=system:serviceaccount:shop:orders-sa -n shop

Test PVC:
kubectl exec -it deploy/orders -n shop -- sh
echo "hello from pvc" > /data/test.txt
cat /data/test.txt


Test PVC:
kubectl run loadgen --rm -it --image=busybox -n shop -- sh
while true; do wget -q -O- http://frontend.shop.svc.cluster.local; done
kubectl get hpa -n shop -w
kubectl get pods -n shop -w

Test KEDA:
kubectl exec -it deploy/orders -n shop -- sh
while true; do :; done
kubectl get scaledobject -n shop
kubectl get hpa -n shop
kubectl get pods -n shop -w