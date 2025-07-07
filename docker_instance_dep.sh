# Create container instance
CONTAINER_NAME="nigh-app-container"
DNS_NAME="nigh-app-$(date +%s)"

az container create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_NAME \
    --image $REGISTRY_SERVER/nigh-app:latest \
    --os-type Linux \
    --registry-login-server $REGISTRY_SERVER \
    --registry-username $REGISTRY_USERNAME \
    --registry-password $REGISTRY_PASSWORD \
    --dns-name-label $DNS_NAME \
    --ports 8080 \
    --environment-variables \
        SECRET_KEY="$SECRET_KEY" \
        USER1_PASSWORD="$USER1_PASSWORD" \
        USER2_PASSWORD="$USER2_PASSWORD" \
        PORT="8080" \
    --cpu 4 \
    --memory 8 \
    --restart-policy Always

# Get the application URL
FQDN=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.fqdn --output tsv)
echo "Application URL: http://$FQDN:8080"