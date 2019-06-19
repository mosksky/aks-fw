az login --service-principal -u %TF_VAR_client_id% -p %TF_VAR_client_secret% -t %TF_VAR_tenant_id%

$SUBSCRIPTION_ID="44c8c436-91c2-xxxxxxx" # here enter your subscription id
$KUBE_GROUP="000-MS-POC-RG-WESTUS" # here enter the resources group name of your AKS cluster
$KUBE_NAME="kubelenvolk" # here enter the name of your kubernetes resource
$LOCATION="westus" # here enter the datacenter location
$KUBE_VNET_NAME="knets" # here enter the name of your vnet
$KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
$KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
$KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
$FW_NAME="kubenetfw" # here enter the name of your azure firewall resource
$FW_IP_NAME="azureFirewalls-ip" # here enter the name of your public ip resource for the firewall
az aks get-versions --location $LOCATION -o table
$KUBE_VERSION="1.12.8" # here enter the kubernetes version of your AKS
$SERVICE_PRINCIPAL_ID= "23a6fc14-8f41-440b-aee7-93f0e3d02e94" # here enter the service principal of your AKS
$SERVICE_PRINCIPAL_SECRET= "xxxxxx" # here enter the service principal secret

### 1. Select subscription, create the resource group and the vnet
az account set --subscription $SUBSCRIPTION_ID
#az group create -n $KUBE_GROUP -l $LOCATION
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME #10.0.0.0/16

### 2. Assign permissions on vnet for your service principal — usually “virtual machine contributor” is enough
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

### 3. Create subnets for the firewall, ingress and AKS
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 `
                                             --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage

### Basic Networking
$KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 `
--network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID `
--docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 `
--service-cidr 10.2.0.0/24 `
--client-secret $SERVICE_PRINCIPAL_SECRET `
--service-principal $SERVICE_PRINCIPAL_ID `
--kubernetes-version $KUBE_VERSION --no-ssh-key

### UDR
az extension add --name azure-firewall
$FW_ROUTE_NAME="${FW_NAME}_fw_r"
$FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_IP_NAME --query ipAddress)
$FW_PRIVATE_IP="10.0.3.4"
$AKS_MC_RG=$(az group list --query "[?starts_with(name, 'MC_${KUBE_GROUP}')].name | [0]" --output tsv)
$ROUTE_TABLE_ID=$(az network route-table list -g ${AKS_MC_RG} --query "[].id | [0]" -o tsv)
$ROUTE_TABLE_NAME=$(az network route-table list -g ${AKS_MC_RG} --query "[].name | [0]" -o tsv)
$AKS_NODE_NSG=$(az network nsg list -g ${AKS_MC_RG} --query "[].id | [0]" -o tsv)
az network vnet subnet update --resource-group $KUBE_GROUP --route-table $ROUTE_TABLE_ID --network-security-group $AKS_NODE_NSG --ids $KUBE_AGENT_SUBNET_ID
az network route-table route create --resource-group $AKS_MC_RG --name $FW_ROUTE_NAME `
--route-table-name $ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance `
--next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION_ID

### create the routetable and the route
$FW_ROUTE_NAME="${FW_NAME}_fw_r"
$FW_ROUTE_TABLE_NAME="${FW_NAME}_fw_rt"
$FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_IP_NAME --query ipAddress)
$FW_PRIVATE_IP="10.0.3.4"
az network route-table create -g $KUBE_GROUP --name $FW_ROUTE_TABLE_NAME
az network vnet subnet update --resource-group $KUBE_GROUP --route-table $FW_ROUTE_TABLE_NAME --ids $KUBE_AGENT_SUBNET_ID
az network route-table route create `
--resource-group $KUBE_GROUP --name $FW_ROUTE_NAME `
--route-table-name $FW_ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 `
--next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP `
--subscription $SUBSCRIPTION_ID

### For AKS to work you need to allow the following network traffic in the subnet   
az network firewall network-rule create `
--firewall-name $FW_NAME --collection-name "aksnetwork" `
--destination-addresses "*"  --destination-ports 22 443 --name "allow network" `
--protocols "TCP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" `
--description "aks network rule" --priority 100   
                                        
az network firewall application-rule create  `
--firewall-name $FW_NAME --collection-name "aksbasics" --name "allow network" `
--protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP `
--action "Allow" --target-fqdns "*.azmk8s.io" "*auth.docker.io" "*cloudflare.docker.io" "*cloudflare.docker.com" "*registry-1.docker.io" `
--priority 100

az network firewall application-rule create  `
--firewall-name $FW_NAME --collection-name "akstools" --name "allow network" `
--protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP `
--action "Allow" --target-fqdns "download.opensuse.org" "login.microsoftonline.com" "*.ubuntu.com" "*azurecr.io" "*blob.core.windows.net" "dc.services.visualstudio.com" "*.opinsights.azure.com" `
--priority 101

az network firewall application-rule create  `
--firewall-name $FW_NAME --collection-name "osupdates" `
--name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP `
--action "Allow" --target-fqdns "download.opensuse.org" "*.ubuntu.com" `
--priority 102