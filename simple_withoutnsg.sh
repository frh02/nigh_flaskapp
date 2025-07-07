#!/bin/bash

# Simple Application Gateway Fix - Remove NSG association
set -e

echo "=== Simple Application Gateway Fix ==="

# Configuration
RESOURCE_GROUP="cv-app-rg"
VNET_NAME="cv-app-vnet"
SUBNET_NAME="cv-app-subnet"
AG_NAME="cv-app-gateway"

# Step 1: Remove NSG from subnet
echo "Removing NSG from Application Gateway subnet..."
az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --remove networkSecurityGroup

echo "NSG removed from subnet successfully!"

# Step 2: Delete and recreate Application Gateway
echo "Deleting existing Application Gateway..."
az network application-gateway delete --name $AG_NAME --resource-group $RESOURCE_GROUP --no-wait

echo "Waiting for deletion to complete..."
sleep 30

# Get container IP
CONTAINER_IP=$(az container show --resource-group $RESOURCE_GROUP --name cv-app-container --query ipAddress.ip --output tsv)
echo "Container IP: $CONTAINER_IP"

# Create Application Gateway
echo "Creating Application Gateway..."
az network application-gateway create \
    --name $AG_NAME \
    --location eastus \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --capacity 2 \
    --sku Standard_v2 \
    --http-settings-cookie-based-affinity Disabled \
    --frontend-port 80 \
    --http-settings-port 8080 \
    --http-settings-protocol Http \
    --public-ip-address cv-app-public-ip \
    --servers $CONTAINER_IP \
    --priority 1000

# Get Application Gateway IP
AG_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name cv-app-public-ip --query ipAddress --output tsv)

echo ""
echo "=== APPLICATION GATEWAY CREATED ==="
echo "Application Gateway URL: http://$AG_IP"
echo ""
echo "=== TESTING ==="
echo "Waiting for Application Gateway to be ready..."
sleep 60

echo "Testing Application Gateway..."
curl -f http://$AG_IP/ || echo "Application Gateway test failed - may need more time"

echo ""
echo "=== NOTES ==="
echo "- NSG has been removed from the Application Gateway subnet"
echo "- This means the Application Gateway is now publicly accessible"
echo "- If you need IP restrictions, consider using Application Gateway's built-in WAF rules"
echo "- Or create a separate subnet for your backend resources with NSG rules"