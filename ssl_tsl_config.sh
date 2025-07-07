#!/bin/bash

# SSL/TLS Configuration Script

RESOURCE_GROUP="cv-app-rg"
AG_NAME="cv-app-gateway"
CERT_NAME="cv-app-ssl-cert"
DOMAIN_NAME="your-domain.com"  # Replace with your domain

# Method 1: Use Azure Key Vault for SSL Certificate Management
KEYVAULT_NAME="cv-app-keyvault-$(date +%s)"

# Create Key Vault
az keyvault create \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location eastus \
    --enabled-for-template-deployment true

# Create self-signed certificate (for testing)
az keyvault certificate create \
    --vault-name $KEYVAULT_NAME \
    --name $CERT_NAME \
    --policy '{
        "issuerParameters": {
            "name": "Self"
        },
        "keyProperties": {
            "exportable": true,
            "keySize": 2048,
            "keyType": "RSA"
        },
        "secretProperties": {
            "contentType": "application/x-pkcs12"
        },
        "x509CertificateProperties": {
            "subject": "CN='$DOMAIN_NAME'",
            "validityInMonths": 12
        }
    }'

# Get certificate ID
CERT_ID=$(az keyvault certificate show \
    --vault-name $KEYVAULT_NAME \
    --name $CERT_NAME \
    --query id \
    --output tsv)

# Create managed identity for Application Gateway
az identity create \
    --resource-group $RESOURCE_GROUP \
    --name cv-app-identity

# Get identity details
IDENTITY_ID=$(az identity show \
    --resource-group $RESOURCE_GROUP \
    --name cv-app-identity \
    --query id \
    --output tsv)

IDENTITY_PRINCIPAL_ID=$(az identity show \
    --resource-group $RESOURCE_GROUP \
    --name cv-app-identity \
    --query principalId \
    --output tsv)

# Assign identity to Application Gateway
az network application-gateway identity assign \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --identity $IDENTITY_ID

# Grant Key Vault access to the identity
az keyvault set-policy \
    --name $KEYVAULT_NAME \
    --object-id $IDENTITY_PRINCIPAL_ID \
    --secret-permissions get \
    --certificate-permissions get

# Add HTTPS listener
az network application-gateway frontend-port create \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name httpsPort \
    --port 443

# Add SSL certificate to Application Gateway
az network application-gateway ssl-cert create \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name $CERT_NAME \
    --key-vault-secret-id $CERT_ID

# Create HTTPS listener
az network application-gateway http-listener create \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name httpsListener \
    --frontend-port httpsPort \
    --ssl-cert $CERT_NAME

# Create HTTPS rule
az network application-gateway rule create \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name httpsRule \
    --http-listener httpsListener \
    --rule-type Basic \
    --address-pool appGatewayBackendPool \
    --http-settings appGatewayBackendHttpSettings

# Method 2: Force HTTPS redirect
az network application-gateway redirect-config create \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name httpToHttpsRedirect \
    --type Permanent \
    --target-listener httpsListener

# Update HTTP rule to redirect to HTTPS
az network application-gateway rule update \
    --gateway-name $AG_NAME \
    --resource-group $RESOURCE_GROUP \
    --name rule1 \
    --redirect-config httpToHttpsRedirect

echo "SSL/TLS setup completed!"
echo "Key Vault Name: $KEYVAULT_NAME"
echo "Certificate Name: $CERT_NAME"
echo "Your application will be available at: https://your-domain.com"