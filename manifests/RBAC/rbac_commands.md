kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-serviceaccount.yaml
kubectl apply -f 03-role.yaml
kubectl apply -f 04-rolebinding.yaml
kubectl apply -f 05-pod.yaml
kubectl apply -f 06-testpod.yaml
kubectl apply -f 07-clusterrole.yaml
kubectl apply -f 08-clusterrolebinding.yaml



kubectl get ns
kubectl get sa -n rbac-demo
kubectl get role -n rbac-demo
kubectl get rolebinding -n rbac-demo
kubectl get clusterrole namespace-reader
kubectl get clusterrolebinding namespace-reader-binding
kubectl get pods -n rbac-demo


kubectl describe sa app-sa -n rbac-demo
kubectl describe role pod-reader -n rbac-demo
kubectl describe rolebinding pod-reader-binding -n rbac-demo
kubectl describe clusterrole namespace-reader
kubectl describe clusterrolebinding namespace-reader-binding
kubectl describe pod app-pod -n rbac-demo


kubectl auth can-i list pods --as=system:serviceaccount:rbac-demo:app-sa -n rbac-demo
kubectl auth can-i get pods --as=system:serviceaccount:rbac-demo:app-sa -n rbac-demo
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-demo:app-sa -n rbac-demo
kubectl auth can-i list services --as=system:serviceaccount:rbac-demo:app-sa -n rbac-demo
kubectl auth can-i list pods --as=system:serviceaccount:rbac-demo:app-sa -n default
kubectl auth can-i list namespaces --as=system:serviceaccount:rbac-demo:app-sa
kubectl auth can-i get namespaces --as=system:serviceaccount:rbac-demo:app-sa