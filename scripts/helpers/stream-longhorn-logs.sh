#!/bin/bash
# Stream Longhorn logs in real-time
# Usage: ./stream-longhorn-logs.sh [component]
# Components: manager, ui, driver, instance-manager, all

set -e

# Set kubeconfig if not already set
if [ -z "$KUBECONFIG" ]; then
    export KUBECONFIG="$(dirname "$(dirname "$0")")/ansible/kubeconfig"
fi

NAMESPACE="longhorn-system"
COMPONENT="${1:-manager}"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

case "$COMPONENT" in
    manager)
        print_header "Streaming Longhorn Manager Logs"
        kubectl logs -n "$NAMESPACE" -l app=longhorn-manager --tail=100 -f --prefix=true
        ;;
    ui)
        print_header "Streaming Longhorn UI Logs"
        kubectl logs -n "$NAMESPACE" -l app=longhorn-ui --tail=100 -f --prefix=true
        ;;
    driver)
        print_header "Streaming Longhorn Driver Deployer Logs"
        kubectl logs -n "$NAMESPACE" -l app=longhorn-driver-deployer --tail=100 -f --prefix=true
        ;;
    instance-manager)
        print_header "Streaming Instance Manager Logs"
        kubectl logs -n "$NAMESPACE" -l longhorn.io/component=instance-manager --tail=100 -f --prefix=true
        ;;
    all)
        print_header "Streaming All Longhorn Logs"
        kubectl logs -n "$NAMESPACE" --all-containers=true --tail=100 -f --prefix=true
        ;;
    *)
        echo "Unknown component: $COMPONENT"
        echo "Usage: $0 [manager|ui|driver|instance-manager|all]"
        echo ""
        echo "Available pods:"
        kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels
        exit 1
        ;;
esac
