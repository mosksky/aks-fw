#Only on the master, download the yaml files for the pod network
wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

#Look inside calico.yaml and find the network range, adjust if needed.
vi calico.yaml

#Create our kubernetes cluster, specifying a pod network range matching that in calico.yaml!
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

#Configure our account on the master to have admin access to the API server from a non-privileged account.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# You should now deploy a pod network to the cluster.
# Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#   https://kubernetes.io/docs/concepts/cluster-administration/addons/

# Then you can join any number of worker nodes by running the following on each as root:
# kubeadm join 172.16.94.10:6443 --token 6perzm.uvf1iavcowcazkzy \
    --discovery-token-ca-cert-hash sha256:707a608969a5ef0dc05358e59d5f5ad2f585fd0b0d0b0d5dce34e14b3214fe12

#Download yaml files for your pod network
kubectl apply -f rbac-kdd.yaml
kubectl apply -f calico.yaml

#Look for the all the system pods and calico pod to change to Running. 
#The DNS pod won't start until the Pod network is deployed and Running.
kubectl get pods --all-namespaces

#Gives you output over time, rather than repainting the screen on each iteration.
kubectl get pods --all-namespaces --watch

#All system pods should be Running
kubectl get pods --all-namespaces

#Get a list of our current nodes, just the master.
kubectl get nodes 

#Check out the systemd unit, and examine 10-kubeadm.conf
#Remeber the kubelet starts static pod manifests, and thus the core cluster pods
sudo systemctl status kubelet.service 

#check out the directory where the kubeconfig files live
ls /etc/kubernetes

#let's check out the manifests on the master
ls /etc/kubernetes/manifests

#And look more closely at API server and etcd's manifest.
sudo more /etc/kubernetes/manifests/etcd.yaml
sudo more /etc/kubernetes/manifests/kube-apiserver.yaml
