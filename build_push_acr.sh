# Login to ACR
az acr login --name $REGISTRY_NAME

# Build image
docker build -t $REGISTRY_SERVER/nigh-app:latest .

# Push image
docker push $REGISTRY_SERVER/nigh-app:latest
