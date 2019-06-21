
# before you begin - make sure you're logged in to the azure CLI
az login --service-principal -u %TF_VAR_client_id% -p %TF_VAR_client_secret% -t %TF_VAR_tenant_id%
# ensure you choose the correct azure subscription if you have more than one 
az account set -s SEC-POLICY-POC

# create a resource group
$resourceGroup = "000-MS-POC-RG-WESTUS"
$location = "westus"
az group create -n $resourceGroup -l $location

Function Get-RandomString($length)
{
    $validChars = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWZYZ".ToCharArray()
    Return -join ((1..$length) | ForEach-Object { $validChars | Get-Random | ForEach-Object {[char]$_} })
}
# create a new container group using the ghost blog image
$containerGroupName = "ghost-blog1"
az container create `
    -g $resourceGroup -n $containerGroupName `
    --image ghost `
    --ports 2368 `
    --ip-address public `
    --dns-name-label "ghost$((Get-RandomString 4).ToLower())"

# show container info
az container show `
    -g $resourceGroup -n $containerGroupName

# find out the domain name
$fqdn = az container show `
    -g $resourceGroup `
    -n $containerGroupName `
    --query ipAddress.fqdn `
    -o tsv

# visit the blog home page
$site = "http://$($fqdn):2368"

Start-Process $site

# visit the blog admin page
Start-Process "$site/ghost"

# check the logs for this container group
az container logs `
    -n $containerGroupName -g $resourceGroup 

# delete the resource group including the container group
az group delete -n $resourceGroup -y --no-wait
#az group deployment create --mode complete --template-file C:\Terraform\AKS-FW\removeall.json --resource-group $resourceGroup
