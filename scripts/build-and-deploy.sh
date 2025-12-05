#!/bin/bash
# Automated script to build Docker images with Socket.IO patches and deploy
set -e

REGISTRY="node0.research.core:5000"
REGISTRY_IP="10.0.0.160:5000"
OTS_VERSION="1.6.3"

echo "========================================="
echo "Building and Deploying OpenTAKServer"
echo "with Socket.IO Patches"
echo "========================================="
echo ""

# Step 1: Configure Docker for insecure registry
echo "Step 1: Configuring Docker for insecure registry..."
sudo mkdir -p /etc/docker
echo "{
  \"insecure-registries\": [\"${REGISTRY}\", \"${REGISTRY_IP}\"]
}" | sudo tee /etc/docker/daemon.json > /dev/null

echo "Restarting Docker..."
sudo systemctl restart docker
sleep 3

# Step 2: Push images to registry
echo ""
echo "Step 2: Pushing images to registry..."
docker push ${REGISTRY}/opentakserver:${OTS_VERSION}
docker push ${REGISTRY}/opentakserver:latest
docker push ${REGISTRY}/opentakserver-ui:master
docker push ${REGISTRY}/opentakserver-ui:latest

# Step 3: Verify registry
echo ""
echo "Step 3: Verifying registry..."
curl -s http://${REGISTRY}/v2/_catalog | jq '.'

# Step 4: Delete existing deployment
echo ""
echo "Step 4: Deleting existing deployment..."
kubectl delete deployment opentakserver -n tak --ignore-not-found=true

# Wait for deletion
echo "Waiting for deployment to be fully deleted..."
while kubectl get deployment opentakserver -n tak &> /dev/null; do
    echo -n "."
    sleep 2
done
echo " Done!"

# Step 5: Redeploy with patched images
echo ""
echo "Step 5: Redeploying with patched images..."
kubectl apply -f /tmp/ots-deployment-fixed.yaml

# Step 6: Wait for pod to be running
echo ""
echo "Step 6: Waiting for pod to start..."
kubectl wait --for=condition=ready pod -l app=opentakserver -n tak --timeout=300s

# Step 7: Verify patches
echo ""
echo "Step 7: Verifying Socket.IO patches..."
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')

# Try both Python 3.12 and 3.13 paths
if kubectl exec -n tak ${POD} -c opentakserver -- grep -q "cors_allowed_origins" /app/venv/lib/python3.12/site-packages/opentakserver/extensions.py 2>/dev/null; then
    echo "✓ Socket.IO patches verified (Python 3.12)"
    PATCH_STATUS="SUCCESS"
elif kubectl exec -n tak ${POD} -c opentakserver -- grep -q "cors_allowed_origins" /app/venv/lib/python3.13/site-packages/opentakserver/extensions.py 2>/dev/null; then
    echo "✓ Socket.IO patches verified (Python 3.13)"
    PATCH_STATUS="SUCCESS"
else
    echo "✗ Socket.IO patches NOT found"
    PATCH_STATUS="FAILED"
fi

# Step 8: Summary
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Pod: ${POD}"
echo "Socket.IO Patches: ${PATCH_STATUS}"
echo ""
echo "Access UI at: http://node0.research.core:31080"
echo ""
echo "To check websocket logs:"
echo "  kubectl logs -n tak ${POD} -c nginx --tail=50 | grep socket.io"
echo ""
echo "Expected: HTTP 200 responses instead of 400 errors"
echo ""
