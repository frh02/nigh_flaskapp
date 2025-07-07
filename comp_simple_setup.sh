#!/bin/bash

# Simplified Azure CV Flask App Deployment
set -e

echo "=== Simplified Azure CV Flask App Deployment ==="

# Configuration
RESOURCE_GROUP="cv-app-simple-rg"
LOCATION="eastus"
REGISTRY_NAME="cvappsimple$(date +%s)"
CONTAINER_NAME="cv-app-simple"
DNS_NAME="cv-app-simple-$(date +%s)"

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

# Step 3: Build and Push Docker Image
echo "Building and pushing Docker image..."
az acr login --name $REGISTRY_NAME

# Build for Linux/amd64 platform
docker buildx build --platform linux/amd64 -t $REGISTRY_SERVER/cv-app:latest --push . || {
    echo "Buildx failed, trying regular build..."
    docker build --platform linux/amd64 -t $REGISTRY_SERVER/cv-app:latest .
    docker push $REGISTRY_SERVER/cv-app:latest
}

# Step 4: Generate Simple Credentials
echo "Generating credentials..."
USER_PASSWORD=$(openssl rand -base64 12)  # Shorter password
SECRET_KEY=$(openssl rand -base64 24)     # Shorter secret

# Step 5: Create Container Instance (Simple Configuration)
echo "Creating Container Instance..."
az container create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_NAME \
    --image $REGISTRY_SERVER/cv-app:latest \
    --registry-login-server $REGISTRY_SERVER \
    --registry-username $REGISTRY_USERNAME \
    --registry-password $REGISTRY_PASSWORD \
    --dns-name-label $DNS_NAME \
    --ports 5000 \
    --os-type Linux \
    --environment-variables \
        SECRET_KEY="$SECRET_KEY" \
        USER1_PASSWORD="$USER_PASSWORD" \
        USER2_PASSWORD="$USER_PASSWORD" \
        FLASK_ENV="production" \
        FLASK_DEBUG="False" \
    --cpu 1 \
    --memory 2 \
    --restart-policy Always

# Wait for container to be ready
echo "Waiting for container to start..."
sleep 45

# Get container details
CONTAINER_IP=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.ip --output tsv)
FQDN=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.fqdn --output tsv)

echo "Container deployed at: $CONTAINER_IP"
echo "Container FQDN: $FQDN"

# Step 6: Test Container
echo "Testing container..."
echo "Checking if container is running..."
az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query "instanceView.state" --output tsv

echo "Getting container logs..."
az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --tail 20

echo "Testing container connectivity..."
# Test on port 5000
curl -v -m 15 http://$CONTAINER_IP:5000/ 2>&1 | head -10 || echo "Container not responding on port 5000"

# Test with authentication
curl -v -m 15 -u user1:$USER_PASSWORD http://$CONTAINER_IP:5000/ 2>&1 | head -10 || echo "Container not responding with auth"

# Final output
echo ""
echo "=== DEPLOYMENT COMPLETED ==="
echo "Container URL: http://$FQDN:5000"
echo "Container IP: http://$CONTAINER_IP:5000"
echo ""
echo "=== CREDENTIALS ==="
echo "Username: user1 (or user2)"
echo "Password: $USER_PASSWORD"
echo ""
echo "=== TESTING COMMANDS ==="
echo "Test without auth: curl http://$CONTAINER_IP:5000/"
echo "Test with auth: curl -u user1:$USER_PASSWORD http://$CONTAINER_IP:5000/"
echo "Test with FQDN: curl http://$FQDN:5000/"
echo ""
echo "=== MANAGEMENT COMMANDS ==="
echo "View logs: az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
echo "Restart container: az container restart --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
echo "Delete everything: az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""
echo "=== TROUBLESHOOTING ==="
echo "If container not responding:"
echo "1. Check logs: az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
echo "2. Check status: az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query instanceView.state"
echo "3. Restart: az container restart --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
echo "4. Check processes: az container exec --resource-group $RESOURCE_GROUP --container-name $CONTAINER_NAME --exec-command 'ps aux'"