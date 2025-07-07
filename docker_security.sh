#!/bin/bash

# Enhanced Security Setup with Application Gateway and WAF

RESOURCE_GROUP="cv-app-rg"
LOCATION="eastus"
VNET_NAME="cv-app-vnet"
SUBNET_NAME="cv-app-subnet"
AG_NAME="cv-app-gateway"
PUBLIC_IP_NAME="cv-app-public-ip"

# Create Virtual Network
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix 10.0.0.0/16 \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix 10.0.1.0/24

# Create Public IP for Application Gateway
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --allocation-method Static \
    --sku Standard

# Create Application Gateway with WAF
az network application-gateway create \
    --name $AG_NAME \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --capacity 2 \
    --sku WAF_v2 \
    --http-settings-cookie-based-affinity Disabled \
    --frontend-port 80 \
    --http-settings-port 5000 \
    --http-settings-protocol Http \
    --public-ip-address $PUBLIC_IP_NAME \
    --waf-policy /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/cv-app-waf-policy

# Create WAF Policy
az network application-gateway waf-policy create \
    --name cv-app-waf-policy \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION

# Configure WAF rules
az network application-gateway waf-policy managed-rule rule-set add \
    --policy-name cv-app-waf-policy \
    --resource-group $RESOURCE_GROUP \
    --type OWASP \
    --version 3.2

# Create Network Security Group
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name cv-app-nsg

# Add NSG rule to allow only specific IPs (replace with your allowed IPs)
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name cv-app-nsg \
    --name AllowSpecificIPs \
    --protocol Tcp \
    --priority 1000 \
    --destination-port-range 5000 \
    --source-address-prefixes "YOUR_IP_ADDRESS_1/32" "YOUR_IP_ADDRESS_2/32" \
    --access Allow

# Associate NSG with subnet
az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --network-security-group cv-app-nsg

echo "Security setup completed!"
echo "Application Gateway Public IP:"
az network public-ip show \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --query ipAddress \
    --output tsv