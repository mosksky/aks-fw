# good tutorial available at https://docs.microsoft.com/en-us/azure/container-instances/container-instances-volume-azure-files

# Create az storage https://github.com/Azure/azure-cli-samples/blob/master/storage/files.md
##                  https://docs.microsoft.com/en-us/cli/azure/storage/file?view=azure-cli-latest
az login

$resourceGroup = "AciVolumeDemo"
$location = "westeurope"
az group create -n $resourceGroup -l $location

$storageAccountName = "acishare$(Get-Random `
    -Minimum 1000 -Maximum 10000)"

# create a storage account
az storage account create -g $resourceGroup `
    -n $storageAccountName `
    --sku Standard_LRS

# get the connection string for our storage account
$storageConnectionString = `
    az storage account show-connection-string `
    -n $storageAccountName -g $resourceGroup `
    --query connectionString -o tsv
# export it as an environment variable
$env:AZURE_STORAGE_CONNECTION_STRING = $storageConnectionString

# Create the file share
$shareName="acishare"
$directory="fruit"
az storage share create -n $shareName
az storage share exists -n $shareName

az storage directory create -s $shareName -n $directory

#### upload single file 
$filename = "00E314E83F2158117C553D1FC291A2C56970E79A.jpeg"
$localFile = "C:\_GitHub\ready-aks-security\fruit\$filename"
az storage file upload -s $shareName --source "$localFile" -p $directory


# upload files
$localFile = "C:\_GitHub\ready-aks-security\fruit\"
az storage file upload -s $shareName --source "$localFile" -p $directory

az storage file upload-batch --account-key "DpwQR5nntPDiREh/RgyFE8maGSnt3Oe6JcFDPPS3vCI/yqiUCyJY5BnuJWKkVdSlIf3on37fW1NprmuyAJrusA==" --account-name "acishare8873" --destination $directory --source $localFile


#validate upload 
az storage file list -s $shareName -p $directory














# get the key for this storage account
$storageKey=$(az storage account keys list `
    -g $resourceGroup --account-name $storageAccountName `
    --query "[0].value" --output tsv)

$containerGroupName = "transcode"

$commandLine = "ffmpeg -i /mnt/azfile/$filename -vf" + `
    " ""thumbnail,scale=640:360"" -frames:v 1 /mnt/azfile/thumb.png"

az container create `
    -g $resourceGroup `
    -n $containerGroupName `
    --image jrottenberg/ffmpeg `
    --restart-policy never `
    --azure-file-volume-account-name $storageAccountName `
    --azure-file-volume-account-key $storageKey `
    --azure-file-volume-share-name $shareName `
    --azure-file-volume-mount-path "/mnt/azfile" `
    --command-line $commandLine

az container logs -g $resourceGroup -n $containerGroupName 

az container show -g $resourceGroup -n $containerGroupName

az container show -g $resourceGroup -n $containerGroupName --query provisioningState

az storage file list -s $shareName -o table

$downloadThumbnailPath = "C:\Users\markh\Downloads\thumb.png"
az storage file download -s $shareName -p "thumb.png" `
    --dest $downloadThumbnailPath
Start-Process $downloadThumbnailPath

#az container delete -g $resourceGroup -n $containerGroupName

# delete the resource group (file share and container group)
az group delete -n $resourceGroup -y
