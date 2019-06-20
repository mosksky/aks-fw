
#### to deploy
kubectl create -f .\tutum-deployment.yaml
kubectl create -f .\nodejs-app-deployment.yaml
kubectl get deployments
kubectl get pods

### AKS Deploy pipeline
kubectl config view --raw
