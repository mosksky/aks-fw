
az login --service-principal -u %TF_VAR_client_id% -p %TF_VAR_client_secret% -t %TF_VAR_tenant_id%
az --version
az aks install-cli
"$env:path += 'C:\Users\msadmin\.azure-kubectl'"
========azure cli commands==========

az aks get-credentials --resource-group acscontainer --name csvision-askcluster
az aks browse --resource-group acscontainer --name csvision-askcluster

==============================

Fix dashboard permission issue:

kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

=============================== Managing Cluster

kubectl config current-context                 #to see the current cluster
kubectl config get-contexts                    #to see the lists of the clusters
kubectl config use-context csvision-askcluster #to switch to the cluster in interest

========== Delete Cluster
az aks delete --resource-group acscontainer --name myAKSCluster --no-wait
