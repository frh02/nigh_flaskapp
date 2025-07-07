# #!/bin/bash

# # Fix Application Gateway Creation Script
# set -e

# echo "=== Fixing Application Gateway Creation ==="

# # Configuration (update these to match your existing resources)
# RESOURCE_GROUP="cv-app-rg"
# LOCATION="eastus"
# CONTAINER_NAME="cv-app-container"
# VNET_NAME="cv-app-vnet"
# SUBNET_NAME="cv-app-subnet"
# AG_NAME="cv-app-gateway"
# PUBLIC_IP_NAME="cv-app-public-ip"
# NSG_NAME="cv-app-nsg"

# # Get the container IP address
# echo "Getting container IP address..."
# CONTAINER_IP=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.ip --output tsv)
# echo "Container IP: $CONTAINER_IP"

# # Delete the failed Application Gateway if it exists
# echo "Cleaning up any failed Application Gateway..."
# az network application-gateway delete --name $AG_NAME --resource-group $RESOURCE_GROUP --no-wait || echo "No existing Application Gateway to delete"

# # Wait a moment for cleanup
# sleep 10

# # Create Application Gateway with proper configuration
# echo "Creating Application Gateway with correct configuration..."
# az network application-gateway create \
#     --name $AG_NAME \
#     --location $LOCATION \
#     --resource-group $RESOURCE_GROUP \
#     --vnet-name $VNET_NAME \
#     --subnet $SUBNET_NAME \
#     --capacity 2 \
#     --sku Standard_v2 \
#     --http-settings-cookie-based-affinity Disabled \
#     --frontend-port 80 \
#     --http-settings-port 8080 \
#     --http-settings-protocol Http \
#     --public-ip-address $PUBLIC_IP_NAME \
#     --servers $CONTAINER_IP \
#     --priority 1000

# # Alternative: Create Application Gateway step by step if the above fails
# if [ $? -ne 0 ]; then
#     echo "Simple create failed, trying step-by-step approach..."
    
#     # Create basic Application Gateway first
#     az network application-gateway create \
#         --name $AG_NAME \
#         --location $LOCATION \
#         --resource-group $RESOURCE_GROUP \
#         --vnet-name $VNET_NAME \
#         --subnet $SUBNET_NAME \
#         --capacity 2 \
#         --sku Standard_v2 \
#         --public-ip-address $PUBLIC_IP_NAME \
#         --priority 1000
    
#     # Add backend pool
#     az network application-gateway address-pool create \
#         --gateway-name $AG_NAME \
#         --resource-group $RESOURCE_GROUP \
#         --name appGatewayBackendPool \
#         --servers $CONTAINER_IP
    
#     # Update HTTP settings
#     az network application-gateway http-settings update \
#         --gateway-name $AG_NAME \
#         --resource-group $RESOURCE_GROUP \
#         --name appGatewayBackendHttpSettings \
#         --port 8080 \
#         --protocol Http \
#         --cookie-based-affinity Disabled
    
#     # Update request routing rule with priority
#     az network application-gateway rule update \
#         --gateway-name $AG_NAME \
#         --resource-group $RESOURCE_GROUP \
#         --name rule1 \
#         --priority 1000
# fi

# # Get Application Gateway IP
# AG_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query ipAddress --output tsv)
# echo "Application Gateway IP: $AG_IP"

# # Create Network Security Group if it doesn't exist
# echo "Creating/updating Network Security Group..."
# az network nsg create --resource-group $RESOURCE_GROUP --name $NSG_NAME || echo "NSG already exists"

# # Get current IP
# MY_IP=$(curl -s ifconfig.me)
# echo "Your current IP: $MY_IP"

# # Add rule to allow only your IP (delete existing rule first if it exists)
# az network nsg rule delete \
#     --resource-group $RESOURCE_GROUP \
#     --nsg-name $NSG_NAME \
#     --name AllowMyIP || echo "Rule doesn't exist"

# az network nsg rule create \
#     --resource-group $RESOURCE_GROUP \
#     --nsg-name $NSG_NAME \
#     --name AllowMyIP \
#     --protocol Tcp \
#     --priority 1000 \
#     --destination-port-range 80 \
#     --source-address-prefixes "$MY_IP/32" \
#     --access Allow

# # Associate NSG with the Application Gateway subnet
# az network vnet subnet update \
#     --resource-group $RESOURCE_GROUP \
#     --vnet-name $VNET_NAME \
#     --name $SUBNET_NAME \
#     --network-security-group $NSG_NAME

# # Health Check
# echo "Performing health check..."
# sleep 60  # Wait for Application Gateway to be ready

# # Get container credentials (you'll need to get these from your previous run)
# echo "Please enter the user1 password from your previous deployment:"
# read -s USER1_PASSWORD

# # Test container directly
# FQDN=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.fqdn --output tsv)
# echo "Testing container directly..."
# curl -f -u user1:$USER1_PASSWORD http://$FQDN:8080/ || echo "Direct container test failed"

# # Test through Application Gateway
# echo "Testing through Application Gateway..."
# curl -f http://$AG_IP/ || echo "Application Gateway test failed"

# # Final output
# echo ""
# echo "=== APPLICATION GATEWAY FIXED ==="
# echo "Application Gateway URL: http://$AG_IP"
# echo "Container Direct URL: http://$FQDN:8080"
# echo "Your IP (allowed): $MY_IP"
# echo ""
# echo "=== VERIFICATION COMMANDS ==="
# echo "Check Application Gateway status:"
# echo "  az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP --query 'provisioningState'"
# echo ""
# echo "Check backend health:"
# echo "  az network application-gateway show-backend-health --name $AG_NAME --resource-group $RESOURCE_GROUP"
# echo ""
# echo "Monitor container logs:"
# echo "  az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"

#!/bin/bash

# Fix Application Gateway NSG Rules - Improved Version
set -e

echo "=== Fixing Application Gateway NSG Rules ==="

# Configuration
RESOURCE_GROUP="cv-app-rg"
NSG_NAME="cv-app-nsg"
VNET_NAME="cv-app-vnet"
SUBNET_NAME="cv-app-subnet"
AG_NAME="cv-app-gateway"
PUBLIC_IP_NAME="cv-app-public-ip"
CONTAINER_NAME="cv-app-container"
LOCATION="eastus"

# Get current IP
MY_IP=$(curl -s ifconfig.me)
echo "Your current IP: $MY_IP"

# Function to wait for operation completion
wait_for_operation() {
    local operation_url="$1"
    local max_attempts=60
    local attempt=0
    
    echo "Waiting for operation to complete..."
    while [ $attempt -lt $max_attempts ]; do
        local status=$(curl -s -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)" "$operation_url" | grep -o '"status":"[^"]*' | cut -d'"' -f4 2>/dev/null || echo "InProgress")
        
        if [ "$status" = "Succeeded" ]; then
            echo "Operation completed successfully!"
            return 0
        elif [ "$status" = "Failed" ]; then
            echo "Operation failed!"
            return 1
        fi
        
        echo "Attempt $((attempt + 1))/$max_attempts: Status = $status"
        sleep 30
        attempt=$((attempt + 1))
    done
    
    echo "Operation timed out after $((max_attempts * 30)) seconds"
    return 1
}

# Step 1: Check if Application Gateway exists and get its status
echo "Checking Application Gateway status..."
AG_EXISTS=$(az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP --query "name" -o tsv 2>/dev/null || echo "")

if [ -n "$AG_EXISTS" ]; then
    echo "Application Gateway exists. Checking provisioning state..."
    AG_STATE=$(az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" -o tsv)
    echo "Current Application Gateway state: $AG_STATE"
    
    if [ "$AG_STATE" != "Succeeded" ]; then
        echo "Application Gateway is not in Succeeded state. Waiting for current operation to complete..."
        sleep 60
    fi
fi

# Step 2: Add required NSG rules (only if they don't exist)
echo "Adding Application Gateway v2 required rules..."

# Check and add Application Gateway v2 management traffic rule
if ! az network nsg rule show --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowApplicationGatewayV2 >/dev/null 2>&1; then
    echo "Adding AllowApplicationGatewayV2 rule..."
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowApplicationGatewayV2 \
        --protocol Tcp \
        --priority 900 \
        --destination-port-range 65200-65535 \
        --source-address-prefixes GatewayManager \
        --access Allow \
        --direction Inbound
else
    echo "AllowApplicationGatewayV2 rule already exists"
fi

# Check and add HTTP rule
if ! az network nsg rule show --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowHTTP >/dev/null 2>&1; then
    echo "Adding AllowHTTP rule..."
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowHTTP \
        --protocol Tcp \
        --priority 1100 \
        --destination-port-range 80 \
        --source-address-prefixes Internet \
        --access Allow \
        --direction Inbound
else
    echo "AllowHTTP rule already exists"
fi

# Check and add HTTPS rule
if ! az network nsg rule show --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowHTTPS >/dev/null 2>&1; then
    echo "Adding AllowHTTPS rule..."
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowHTTPS \
        --protocol Tcp \
        --priority 1200 \
        --destination-port-range 443 \
        --source-address-prefixes Internet \
        --access Allow \
        --direction Inbound
else
    echo "AllowHTTPS rule already exists"
fi

# Update existing rule for your IP
if az network nsg rule show --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --name AllowMyIP >/dev/null 2>&1; then
    echo "Updating AllowMyIP rule..."
    az network nsg rule update \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowMyIP \
        --source-address-prefixes "$MY_IP/32"
else
    echo "Creating AllowMyIP rule..."
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name AllowMyIP \
        --protocol Tcp \
        --priority 1000 \
        --destination-port-range 80 \
        --source-address-prefixes "$MY_IP/32" \
        --access Allow \
        --direction Inbound
fi

echo "NSG rules updated successfully!"

# Step 3: Remove NSG from subnet temporarily
echo "Temporarily removing NSG from subnet..."
az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --remove networkSecurityGroup

# Wait for subnet update to complete
sleep 15

# Step 4: Delete Application Gateway if it exists and wait for complete deletion
if [ -n "$AG_EXISTS" ]; then
    echo "Deleting existing Application Gateway..."
    
    # Start deletion (synchronous)
    az network application-gateway delete --name $AG_NAME --resource-group $RESOURCE_GROUP
    
    # Wait additional time to ensure complete cleanup
    echo "Waiting for complete cleanup..."
    sleep 60
    
    # Verify deletion
    while az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; do
        echo "Still deleting... waiting 30 more seconds"
        sleep 30
    done
    
    echo "Application Gateway deletion confirmed"
fi

# Step 5: Get container IP
echo "Getting container IP..."
CONTAINER_IP=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.ip --output tsv)
echo "Container IP: $CONTAINER_IP"

# Step 6: Create Application Gateway without NSG first
echo "Creating Application Gateway (this may take 10-15 minutes)..."
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
    --servers $CONTAINER_IP \
    --priority 1000

# Wait for Application Gateway to be fully ready
echo "Waiting for Application Gateway to be fully provisioned..."
sleep 60

# Verify Application Gateway is ready
AG_STATE=$(az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" -o tsv)
echo "Application Gateway state: $AG_STATE"

if [ "$AG_STATE" != "Succeeded" ]; then
    echo "Waiting for Application Gateway to reach Succeeded state..."
    sleep 120
fi

# Step 7: Re-associate NSG with subnet after Application Gateway is created
echo "Re-associating NSG with subnet..."
az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --network-security-group $NSG_NAME

# Get Application Gateway IP
AG_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query ipAddress --output tsv)

echo ""
echo "=== APPLICATION GATEWAY FIXED ==="
echo "Application Gateway URL: http://$AG_IP"
echo "Container IP: $CONTAINER_IP"
echo ""
echo "=== NSG RULES ADDED ==="
echo "- Application Gateway v2 management traffic (ports 65200-65535)"
echo "- HTTP traffic from internet (port 80)"
echo "- HTTPS traffic from internet (port 443)"
echo "- Your IP access (port 80): $MY_IP"
echo ""
echo "=== TESTING ==="
echo "Waiting for Application Gateway to be ready for traffic..."
sleep 60

echo "Testing Application Gateway..."
for i in {1..5}; do
    echo "Test attempt $i/5..."
    if curl -f -m 30 http://$AG_IP/; then
        echo "✓ Application Gateway test successful!"
        break
    else
        echo "✗ Application Gateway test failed, retrying in 30 seconds..."
        sleep 30
    fi
done

echo ""
echo "=== VERIFICATION COMMANDS ==="
echo "Check Application Gateway status:"
echo "  az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP --query 'provisioningState'"
echo ""
echo "Check backend health:"
echo "  az network application-gateway show-backend-health --name $AG_NAME --resource-group $RESOURCE_GROUP"
echo ""
echo "List NSG rules:"
echo "  az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $NSG_NAME --output table"
echo ""
echo "Monitor container logs:"
echo "  az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"