# create a resource group
$resourceGroup = "000-MS-POC-RG-WESTUS"
$location = "westus"
#az group create -n $resourceGroup -l $location

Function Get-RandomString($length)
{
    $validChars = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWZYZ".ToCharArray()
    Return -join ((1..$length) | ForEach-Object { $validChars | Get-Random | ForEach-Object {[char]$_} })
}

# create our container running a Windows ASP.NET Core application
$containerGroupName = "miniblog-win"
az container create -g $resourceGroup -n $containerGroupName `
    --image markheath/miniblogcore:v1 `
    --ip-address public `
    --dns-name-label "miniblog-win$((Get-RandomString 4).ToLower())" `
    --os-type windows `
    --memory 2 --cpu 2 `
    --restart-policy OnFailure
   
az container show `
    -g $resourceGroup -n $containerGroupName
    
# get its domain name:
$fqdn = az container show -g $resourceGroup -n $containerGroupName --query ipAddress.fqdn -o tsv

# visit the site in a browser
$site = "http://$($fqdn)"

Start-Process $site

# inspect the logs
az container logs -n $containerGroupName -g $resourceGroup 

# when we're done, clean up by deleting the resource group
az group delete -n $resourceGroup -y --no-wait