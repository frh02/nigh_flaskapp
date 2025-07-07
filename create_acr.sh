# Set variables
RESOURCE_GROUP="nigh-app-rg"
LOCATION="eastus"
REGISTRY_NAME="nighappregistry$(date +%s)"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create container registry
az acr create --resource-group $RESOURCE_GROUP --name $REGISTRY_NAME --sku Basic --admin-enabled true

# Get registry credentials
REGISTRY_SERVER=$(az acr show --name $REGISTRY_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
REGISTRY_USERNAME=$(az acr credential show --name $REGISTRY_NAME --query "username" --output tsv)
REGISTRY_PASSWORD=$(az acr credential show --name $REGISTRY_NAME --query "passwords[0].value" --output tsv)

echo "Registry Server: $REGISTRY_SERVER"
echo "Registry Username: $REGISTRY_USERNAME"
echo "Registry Password: $REGISTRY_PASSWORD"