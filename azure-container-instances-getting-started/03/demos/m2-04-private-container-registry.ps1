# create a resource group to use
$resourceGroup = "000-MS-POC-RG-WESTUS"
$location = "westus"
#az group create -n $resourceGroup -l $location

# create an Azure Container Registry
$acrName = "lenvolkacr"
az acr create -g $resourceGroup -n $acrName `
    --sku Basic --admin-enabled true

# login to the registry with docker
$acrPassword = az acr credential show -n $acrName `
    --query "passwords[0].value" -o tsv
$loginServer = az acr show -n $acrName `
    --query loginServer --output tsv

### !!! Make sure docker is running
docker login -u $acrName -p $acrPassword $loginServer 

# see the images we have - should have samplewebapp:v2
docker image ls

# tag the image we want to use in our registry
$image = "samplewebapp"
$imageTag = "$loginServer/$image"
docker tag $image $imageTag

# push the image to our registry
docker push $imageTag

# see what images are in our registry
az acr repository list -n $acrName --output table
##############################
# create a new container group using the image from the private registry
$containerGroupName = "aci-acr"
az container create -g $resourceGroup `
    -n $containerGroupName `
    --image $imageTag --cpu 1 --memory 1 `
    --registry-username $acrName `
    --registry-password $acrPassword `
    --dns-name-label "aciacrlenvolk" --ports 80

# get the site address and launch in a browser
$fqdn = az container show -g $resourceGroup -n $containerGroupName `
    --query ipAddress.fqdn -o tsv
Start-Process "http://$($fqdn)"

# view the logs for our container
az container logs -n $containerGroupName -g $resourceGroup

# delete the resource group (ACR and container group)
az group delete -n $resourceGroup -y --no-wait
