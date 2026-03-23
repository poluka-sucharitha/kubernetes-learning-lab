cd /tmp
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
cd csi-driver-host-path

# optional: check your cluster version
kubectl version --short

# deploy the hostpath CSI driver
./deploy/kubernetes-latest/deploy.sh