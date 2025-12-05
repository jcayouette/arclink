#!/bin/bash
# Build script for OpenTAKServer custom images
# Builds for ARM64 architecture (Raspberry Pi 5)

set -e

REGISTRY="${REGISTRY:-localhost:5000}"
OTS_VERSION="${OTS_VERSION:-1.6.3}"
UI_VERSION="${UI_VERSION:-master}"

echo "Building OpenTAKServer images..."
echo "Registry: ${REGISTRY}"
echo "OTS Version: ${OTS_VERSION}"
echo "UI Version: ${UI_VERSION}"

# Build OpenTAKServer image
echo ""
echo "Building OpenTAKServer image..."

# Determine script directory and set paths accordingly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$PWD")" = "docker" ]; then
    # Running from docker directory
    OTS_DOCKERFILE="opentakserver/Dockerfile"
    OTS_CONTEXT="opentakserver/"
    UI_DOCKERFILE="ui/Dockerfile"
    UI_CONTEXT="ui/"
else
    # Running from root directory
    OTS_DOCKERFILE="docker/opentakserver/Dockerfile"
    OTS_CONTEXT="docker/opentakserver/"
    UI_DOCKERFILE="docker/ui/Dockerfile"
    UI_CONTEXT="docker/ui/"
fi

docker build \
    --platform linux/arm64 \
    --build-arg OTS_VERSION=${OTS_VERSION} \
    -t ${REGISTRY}/opentakserver:${OTS_VERSION} \
    -t ${REGISTRY}/opentakserver:latest \
    -f ${OTS_DOCKERFILE} \
    ${OTS_CONTEXT}

# Build UI image
echo ""
echo "Building OpenTAKServer UI image..."
docker build \
    --platform linux/arm64 \
    --build-arg UI_VERSION=${UI_VERSION} \
    -t ${REGISTRY}/opentakserver-ui:${UI_VERSION} \
    -t ${REGISTRY}/opentakserver-ui:latest \
    -f ${UI_DOCKERFILE} \
    ${UI_CONTEXT}

echo ""
echo "Build complete!"
echo ""
echo "To push to registry:"
echo "  docker push ${REGISTRY}/opentakserver:${OTS_VERSION}"
echo "  docker push ${REGISTRY}/opentakserver:latest"
echo "  docker push ${REGISTRY}/opentakserver-ui:${UI_VERSION}"
echo "  docker push ${REGISTRY}/opentakserver-ui:latest"
echo ""
echo "To use in k3s without a registry:"
echo "  docker save ${REGISTRY}/opentakserver:latest | sudo k3s ctr images import -"
echo "  docker save ${REGISTRY}/opentakserver-ui:latest | sudo k3s ctr images import -"
