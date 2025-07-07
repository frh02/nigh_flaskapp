#!/bin/bash

# Complete Azure Deployment Script for CV Flask Application
set -e

echo "=== Azure CV Flask App Deployment ==="

# Configuration
RESOURCE_GROUP="cv-app-rg"
LOCATION="eastus"
REGISTRY_NAME="cvappregistry$(date +%s)"
CONTAINER_NAME="cv-app-container"
DNS_NAME="cv-app-$(date +%s)"
VNET_NAME="cv-app-vnet"
SUBNET_NAME="cv-app-subnet"
AG_NAME="cv-app-gateway"
PUBLIC_IP_NAME="cv-app-public-ip"
NSG_NAME="cv-app-nsg"

# Step 1: Create Resource Group
echo "Creating Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Step 2: Create Container Registry
echo "Creating Container Registry..."
az acr create --resource-group $RESOURCE_GROUP --name $REGISTRY_NAME --sku Basic --admin-enabled true

# Get registry credentials
REGISTRY_SERVER=$(az acr show --name $REGISTRY_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
REGISTRY_USERNAME=$(az acr credential show --name $REGISTRY_NAME --query "username" --output tsv)
REGISTRY_PASSWORD=$(az acr credential show --name $REGISTRY_NAME --query "passwords[0].value" --output tsv)

echo "Registry created: $REGISTRY_SERVER"

# Step 3: Build and Push Docker Image with correct platform
echo "Building and pushing Docker image..."
az acr login --name $REGISTRY_NAME

# Build for Linux/amd64 platform specifically
docker buildx build --platform linux/amd64 -t $REGISTRY_SERVER/cv-app:latest --push .

# Alternative: If buildx is not available, build and push separately
# docker build --platform linux/amd64 -t $REGISTRY_SERVER/cv-app:latest .
# docker push $REGISTRY_SERVER/cv-app:latest

# Step 4: Generate Secure Credentials
echo "Generating secure credentials..."
USER1_PASSWORD=$(openssl rand -base64 32)
USER2_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)

# Step 5: Create Container Instance with explicit platform specification
echo "Creating Container Instance..."
az container create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_NAME \
    --image $REGISTRY_SERVER/cv-app:latest \
    --registry-login-server $REGISTRY_SERVER \
    --registry-username $REGISTRY_USERNAME \
    --registry-password $REGISTRY_PASSWORD \
    --dns-name-label $DNS_NAME \
    --ports 8080 \
    --os-type Linux \
    --environment-variables \
        SECRET_KEY="$SECRET_KEY" \
        USER1_PASSWORD="$USER1_PASSWORD" \
        USER2_PASSWORD="$USER2_PASSWORD" \
        PORT="8080" \
    --cpu 2 \
    --memory 4 \
    --restart-policy Always

# Wait for container to be ready
echo "Waiting for container to be ready..."
sleep 30

# Get container details
CONTAINER_IP=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.ip --output tsv)
FQDN=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.fqdn --output tsv)

echo "Container deployed at: $CONTAINER_IP"
echo "Container FQDN: $FQDN"

# Step 6: Create Virtual Network
echo "Creating Virtual Network..."
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix 10.0.0.0/16 \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix 10.0.1.0/24

# Step 7: Create Public IP for Application Gateway
echo "Creating Public IP..."
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --allocation-method Static \
    --sku Standard

# Step 8: Create Application Gateway
echo "Creating Application Gateway..."
az network application-gateway create \
    --name $AG_NAME \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --capacity 2 \
    --sku Standard_v2 \
    --http-settings-cookie-based-affinity Disabled \
    --frontend-port 80 \
    --http-settings-port 8080 \
    --http-settings-protocol Http \
    --public-ip-address $PUBLIC_IP_NAME \
    --servers $CONTAINER_IP

# Get Application Gateway IP
AG_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query ipAddress --output tsv)

# Step 9: Create Network Security Group (IP Restriction)
echo "Creating Network Security Group..."
az network nsg create --resource-group $RESOURCE_GROUP --name $NSG_NAME

# Get current IP
MY_IP=$(curl -s ifconfig.me)
echo "Your current IP: $MY_IP"

# Add rule to allow only your IP
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name AllowMyIP \
    --protocol Tcp \
    --priority 1000 \
    --destination-port-range 80 \
    --source-address-prefixes "$MY_IP/32" \
    --access Allow

# Step 10: Health Check
echo "Performing health check..."
sleep 60  # Wait for services to be ready

# Test container directly
echo "Testing container directly..."
curl -f -u user1:$USER1_PASSWORD http://$FQDN:8080/ || echo "Direct container test failed"

# Test through Application Gateway
echo "Testing through Application Gateway..."
curl -f http://$AG_IP/ || echo "Application Gateway test failed"

# Final output
echo ""
echo "=== DEPLOYMENT COMPLETED ==="
echo "Application Gateway URL: http://$AG_IP"
echo "Container Direct URL: http://$FQDN:8080"
echo ""
echo "=== CREDENTIALS (SAVE THESE!) ==="
echo "Username: user1"
echo "Password: $USER1_PASSWORD"
echo "Username: user2"
echo "Password: $USER2_PASSWORD"
echo "Secret Key: $SECRET_KEY"
echo ""
echo "=== RESOURCE INFORMATION ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Container Registry: $REGISTRY_SERVER"
echo "Container Name: $CONTAINER_NAME"
echo "Application Gateway: $AG_NAME"
echo "Your IP (allowed): $MY_IP"
echo ""
echo "=== NEXT STEPS ==="
echo "1. Test the application at: http://$AG_IP"
echo "2. Add more allowed IPs if needed:"
echo "   az network nsg rule update --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowMyIP --source-address-prefixes \"$MY_IP/32\" \"ANOTHER_IP/32\""
echo "3. Monitor logs:"
echo "   az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
echo "4. Clean up when done:"
echo "   az group delete --name $RESOURCE_GROUP --yes --no-wait"