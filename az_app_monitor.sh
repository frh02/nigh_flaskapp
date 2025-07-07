#!/bin/bash

# Monitoring and Logging Setup

RESOURCE_GROUP="cv-app-rg"
WORKSPACE_NAME="cv-app-workspace"
CONTAINER_NAME="cv-app-container"
AG_NAME="cv-app-gateway"

# Create Log Analytics Workspace
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE_NAME \
    --location eastus

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE_NAME \
    --query customerId \
    --output tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $WORKSPACE_NAME \
    --query primarySharedKey \
    --output tsv)

# Enable diagnostics for Application Gateway
az monitor diagnostic-settings create \
    --resource $(az network application-gateway show --name $AG_NAME --resource-group $RESOURCE_GROUP --query id --output tsv) \
    --name gateway-diagnostics \
    --workspace $WORKSPACE_ID \
    --logs '[
        {
            "category": "ApplicationGatewayAccessLog",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        },
        {
            "category": "ApplicationGatewayPerformanceLog",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        }
    ]' \
    --metrics '[
        {
            "category": "AllMetrics",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        }
    ]'

# Create Application Insights
az extension add --name application-insights
az monitor app-insights component create \
    --app cv-app-insights \
    --location eastus \
    --resource-group $RESOURCE_GROUP \
    --workspace $WORKSPACE_ID

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
    --app cv-app-insights \
    --resource-group $RESOURCE_GROUP \
    --query instrumentationKey \
    --output tsv)

# Create alert rules
az monitor metrics alert create \
    --name "High CPU Usage" \
    --resource-group $RESOURCE_GROUP \
    --scopes $(az container show --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --query id --output tsv) \
    --condition "avg Percentage CPU > 80" \
    --description "Alert when CPU usage exceeds 80%" \
    --evaluation-frequency 1m \
    --window-size 5m \
    --severity 2

az monitor metrics alert create \
    --name "High Memory Usage" \
    --resource-group $RESOURCE_GROUP \
    --scopes $(az container show --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --query id --output tsv) \
    --condition "avg Memory Usage > 3.5" \
    --description "Alert when memory usage exceeds 3.5GB" \
    --evaluation-frequency 1m \
    --window-size 5m \
    --severity 2

# Create custom dashboard
az portal dashboard create \
    --resource-group $RESOURCE_GROUP \
    --name "CV App Dashboard" \
    --input-path dashboard.json

echo "Monitoring setup completed!"
echo "Log Analytics Workspace ID: $WORKSPACE_ID"
echo "Application Insights Instrumentation Key: $INSTRUMENTATION_KEY"
echo "Access your dashboard at: https://portal.azure.com"