#!/bin/bash
# Quick setup script to build and deploy custom OpenTAKServer images
# This will take ~30 minutes on first run, but deployments will be fast afterwards

set -e

echo "========================================="
echo "OpenTAKServer Custom Image Setup"
echo "========================================="
echo ""

# Determine registry approach
echo "Choose your deployment method:"
echo "1) Import directly to k3s (no registry needed)"
echo "2) Use local registry (recommended for multi-node)"
echo "3) Use external registry (DockerHub, etc.)"
echo ""
read -p "Choice [1]: " CHOICE
CHOICE=${CHOICE:-1}

case $CHOICE in
  1)
    REGISTRY="local"
    IMPORT_METHOD="direct"
    echo "Using direct import to k3s"
    ;;
  2)
    read -p "Enter registry address [node0:5000]: " REGISTRY
    REGISTRY=${REGISTRY:-node0:5000}
    IMPORT_METHOD="registry"
    echo "Using local registry: $REGISTRY"
    ;;
  3)
    read -p "Enter registry (e.g., yourusername): " REGISTRY
    IMPORT_METHOD="registry"
    echo "Using external registry: $REGISTRY"
    docker login
    ;;
esac

# Build images
echo ""
echo "Building images (this will take ~30 minutes)..."
export REGISTRY=$REGISTRY
./build.sh

# Import or push
echo ""
if [ "$IMPORT_METHOD" = "direct" ]; then
    echo "Importing images to k3s..."
    docker save ${REGISTRY}/opentakserver:latest | sudo k3s ctr images import -
    docker save ${REGISTRY}/opentakserver-ui:latest | sudo k3s ctr images import -
    
    IMAGE_OTS="${REGISTRY}/opentakserver:latest"
    IMAGE_UI="${REGISTRY}/opentakserver-ui:latest"
    IMAGE_PULL_POLICY="Never"
else
    echo "Pushing images to registry..."
    docker push ${REGISTRY}/opentakserver:latest
    docker push ${REGISTRY}/opentakserver-ui:latest
    
    IMAGE_OTS="${REGISTRY}/opentakserver:latest"
    IMAGE_UI="${REGISTRY}/opentakserver-ui:latest"
    IMAGE_PULL_POLICY="IfNotPresent"
fi

# Update manifest
echo ""
echo "Updating deployment manifest..."

# Determine manifest path based on current directory
if [ "$(basename "$PWD")" = "docker" ]; then
    MANIFEST_PATH="../manifests"
else
    MANIFEST_PATH="manifests"
fi

cp ${MANIFEST_PATH}/ots-with-ui-custom-images.yaml ${MANIFEST_PATH}/ots-with-ui-custom-images.yaml.bak

sed -i "s|image: python:3.12  # REPLACE THIS after building custom image|image: ${IMAGE_OTS}|g" ${MANIFEST_PATH}/ots-with-ui-custom-images.yaml
sed -i "s|image: nginx:alpine  # REPLACE THIS after building custom image|image: ${IMAGE_UI}|g" ${MANIFEST_PATH}/ots-with-ui-custom-images.yaml
sed -i "s|imagePullPolicy: IfNotPresent|imagePullPolicy: ${IMAGE_PULL_POLICY}|g" ${MANIFEST_PATH}/ots-with-ui-custom-images.yaml

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
echo ""
echo "To deploy:"
echo "  kubectl delete -f ${MANIFEST_PATH}/ots-with-ui.yaml  # Remove old deployment"
echo "  kubectl apply -f ${MANIFEST_PATH}/ots-with-ui-custom-images.yaml"
echo ""
echo "Pod restarts will now take seconds instead of minutes!"
echo ""
