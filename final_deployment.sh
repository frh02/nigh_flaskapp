#!/bin/bash

# Complete Deployment Script - Run this after all components are set up

set -e

# Configuration
RESOURCE_GROUP="cv-app-rg"
LOCATION="eastus"
REGISTRY_NAME="cvappregistry"
CONTAINER_NAME="cv-app-container"
AG_NAME="cv-app-gateway"

echo "Starting complete deployment..."

# 1. Build and push Docker image
echo "Building Docker image..."
docker build -t $REGISTRY_NAME.azurecr.io/cv-app:latest .

echo "Pushing to Azure Container Registry..."
az acr login --name $REGISTRY_NAME
docker push $REGISTRY_NAME.azurecr.io/cv-app:latest

# 2. Generate secure credentials
USER1_PASSWORD=$(openssl rand -base64 32)
USER2_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)

# 3. Deploy container
echo "Deploying container..."
az container create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_NAME \
    --image $REGISTRY_NAME.azurecr.io/cv-app:latest \
    --registry-login-server $REGISTRY_NAME.azurecr.io \
    --registry-username $REGISTRY_NAME \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query "passwords[0].value" --output tsv) \
    --dns-name-label cv-app-$(date +%s) \
    --ports 5000 \
    --environment-variables \
        SECRET_KEY="$SECRET_KEY" \
        USER1_PASSWORD="$USER1_PASSWORD" \
        USER2_PASSWORD="$USER2_PASSWORD" \
    --cpu 2 \
    --memory 4 \
    --restart-policy Always

# 4. Get container IP
CONTAINER_IP=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_NAME \
    --query ipAddress.ip \
    --output tsv)

# 5. Update Application Gateway backend pool
az network application-gateway address-pool update \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name appGatewayBackendPool \
    --servers $CONTAINER_IP

# 6. Get Application Gateway public IP
AG_PUBLIC_IP=$(az network public-ip show \
    --resource-group $RESOURCE_GROUP \
    --name cv-app-public-ip \
    --query ipAddress \
    --output tsv)

# 7. Health check
echo "Performing health check..."