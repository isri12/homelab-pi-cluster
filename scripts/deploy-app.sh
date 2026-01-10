#!/bin/bash
# Script to deploy a Docker image to the K3s cluster
# Usage: ./deploy-app.sh <app-name> <docker-image> <port>

APP_NAME=$1
IMAGE_NAME=$2
PORT=$3

if [ -z "$APP_NAME" ] || [ -z "$IMAGE_NAME" ]; then
    echo "Usage: ./deploy-app.sh <app-name> <docker-image> [port]"
    echo "Example: ./deploy-app.sh my-web-server nginx:latest 80"
    exit 1
fi

if [ -z "$PORT" ]; then
    PORT=80
    echo "ℹ️  No port specified, defaulting to 80"
fi

echo "🚀 Deploying '$APP_NAME' using Docker image '$IMAGE_NAME'..."

# 1. Create the Deployment (Runs the Docker container)
# This tells K8s to pull the image and run it
kubectl create deployment "$APP_NAME" --image="$IMAGE_NAME"

# 2. Expose the Deployment (Creates a Service)
# This allows network access to the container
kubectl expose deployment "$APP_NAME" --port="$PORT" --target-port="$PORT" --type=LoadBalancer --name="$APP_NAME-svc"

echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/"$APP_NAME"

echo ""
echo "✅ Deployment Successful!"
echo "-------------------------"
echo "App: $APP_NAME"
echo "Image: $IMAGE_NAME"

# Get the assigned IP (LoadBalancer IP provided by K3s/ServiceLB)
LB_IP=$(kubectl get svc "$APP_NAME-svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$LB_IP" ]; then
    # If no LB IP yet, it might be pending or using node port
    echo "Service is accessible via any node IP on the assigned NodePort."
    kubectl get svc "$APP_NAME-svc"
else
    echo "URL: http://$LB_IP:$PORT"
fi
