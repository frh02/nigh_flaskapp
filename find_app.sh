#!/bin/bash

# Fixed Application Gateway Script
set -e

echo "=== Application Gateway Fix - Port Corrected ==="

# Configuration
RESOURCE_GROUP="cv-app-rg"
AG_NAME="cv-app-gateway"
CONTAINER_NAME="cv-app-container"

# Get container IP and FQDN
CONTAINER_IP=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.ip --output tsv)
CONTAINER_FQDN=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.fqdn --output tsv)

echo "Container IP: $CONTAINER_IP"
echo "Container FQDN: $CONTAINER_FQDN"

# Check container logs first
echo ""
echo "=== CHECKING CONTAINER LOGS ==="
az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME | tail -20

echo ""
echo "=== TESTING CONTAINER ON CORRECT PORT (5000) ==="
echo "Testing container at $CONTAINER_IP:5000..."

# Test container on port 5000 (the actual port)
echo "Method 1: Testing port 5000 directly"
curl -v -m 10 http://$CONTAINER_IP:5000/ 2>&1 | head -20 || echo "Port 5000 test failed"

echo ""
echo "Method 2: Testing with FQDN on port 5000"
curl -v -m 10 http://$CONTAINER_FQDN:5000/ 2>&1 | head -20 || echo "FQDN port 5000 test failed"

echo ""
echo "=== CHECKING CURRENT BACKEND HTTP SETTINGS ==="
az network application-gateway http-settings show \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name appGatewayBackendHttpSettings

echo ""
echo "=== UPDATING BACKEND HTTP SETTINGS TO PORT 5000 ==="
# Update backend HTTP settings to use port 5000
az network application-gateway http-settings update \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name appGatewayBackendHttpSettings \
    --port 5000 \
    --protocol Http \
    --timeout 30

echo ""
echo "=== UPDATING BACKEND POOL ==="
# Update backend pool with current container IP
az network application-gateway address-pool update \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name appGatewayBackendPool \
    --servers $CONTAINER_IP

echo ""
echo "=== CHECKING NETWORK SECURITY GROUP ==="
# Check if there's an NSG blocking traffic
echo "Checking for NSG rules that might block Application Gateway health probes..."

# Get the Application Gateway subnet
AG_SUBNET=$(az network application-gateway show \
    --name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "gatewayIpConfigurations[0].subnet.id" \
    --output tsv)

if [ ! -z "$AG_SUBNET" ]; then
    echo "Application Gateway subnet: $AG_SUBNET"
    
    # Extract vnet and subnet names
    VNET_NAME=$(echo $AG_SUBNET | cut -d'/' -f9)
    SUBNET_NAME=$(echo $AG_SUBNET | cut -d'/' -f11)
    
    echo "VNet: $VNET_NAME, Subnet: $SUBNET_NAME"
    
    # Check if subnet has NSG associated
    NSG_ID=$(az network vnet subnet show \
        --resource-group $RESOURCE_GROUP \
        --vnet-name $VNET_NAME \
        --name $SUBNET_NAME \
        --query networkSecurityGroup.id \
        --output tsv 2>/dev/null || echo "none")
    
    if [ "$NSG_ID" != "none" ] && [ ! -z "$NSG_ID" ]; then
        NSG_NAME=$(echo $NSG_ID | cut -d'/' -f9)
        echo "NSG found: $NSG_NAME"
        
        echo "Checking NSG rules for health probe ports..."
        az network nsg rule list \
            --resource-group $RESOURCE_GROUP \
            --nsg-name $NSG_NAME \
            --query "[?direction=='Inbound' && access=='Allow'].{Name:name, Priority:priority, SourcePort:sourcePortRange, DestPort:destinationPortRange, Protocol:protocol}" \
            --output table
    else
        echo "No NSG associated with Application Gateway subnet"
    fi
fi

echo ""
echo "=== CREATING/UPDATING CUSTOM HEALTH PROBE ==="
# Create a custom health probe for port 5000
az network application-gateway probe create \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name customHealthProbe \
    --protocol Http \
    --host-name-from-backend-pool \
    --path "/" \
    --interval 30 \
    --threshold 3 \
    --timeout 30 \
    --port 5000 2>/dev/null || \
az network application-gateway probe update \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name customHealthProbe \
    --protocol Http \
    --host-name-from-backend-pool \
    --path "/" \
    --interval 30 \
    --threshold 3 \
    --timeout 30 \
    --port 5000

echo ""
echo "=== UPDATING BACKEND HTTP SETTINGS TO USE CUSTOM PROBE ==="
az network application-gateway http-settings update \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name appGatewayBackendHttpSettings \
    --probe customHealthProbe

echo ""
echo "=== WAITING FOR CONFIGURATION TO PROPAGATE ==="
echo "Waiting 60 seconds for changes to take effect..."
sleep 60

echo ""
echo "=== TESTING APPLICATION GATEWAY ==="
AG_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name cv-app-public-ip --query ipAddress --output tsv)
echo "Application Gateway IP: $AG_IP"

curl -v -m 15 http://$AG_IP/ 2>&1 | head -20 || echo "Application Gateway still not responding"

echo ""
echo "=== CHECKING BACKEND HEALTH AFTER UPDATES ==="
az network application-gateway show-backend-health --name $AG_NAME --resource-group $RESOURCE_GROUP

echo ""
echo "=== FINAL DIAGNOSTICS ==="
echo "Container IP: $CONTAINER_IP"
echo "Container FQDN: $CONTAINER_FQDN"
echo "Application Gateway IP: $AG_IP"
echo ""
echo "If still not working, try these manual tests:"
echo "1. Test container directly: curl http://$CONTAINER_IP:5000/"
echo "2. Test with FQDN: curl http://$CONTAINER_FQDN:5000/"
echo "3. Check if container needs restart: az container restart --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
echo ""
echo "Common issues to check:"
echo "- Container application might not be binding to 0.0.0.0:5000 (check for localhost binding)"
echo "- Application Gateway subnet NSG might need inbound rules for ports 65200-65535"
echo "- Container might need time to fully start up"