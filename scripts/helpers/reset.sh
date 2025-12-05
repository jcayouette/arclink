#!/bin/bash
# OpenTAK Server Reset Script
# Options: soft reset (keep data) or hard reset (delete everything)

set -e

echo "========================================"
echo "  OpenTAK Server Reset"
echo "========================================"
echo ""

# Check if namespace exists
if ! kubectl get namespace tak &> /dev/null; then
    echo "❌ Namespace 'tak' does not exist. Nothing to reset."
    exit 0
fi

# Parse command line arguments
HARD_RESET=false
if [[ "$1" == "--hard" || "$1" == "-h" ]]; then
    HARD_RESET=true
fi

if [ "$HARD_RESET" = true ]; then
    echo "🔥 HARD RESET: Deleting entire namespace including all data"
    echo "⚠️  This will permanently delete all PostgreSQL data!"
    echo ""
    read -p "Are you sure? (yes/no): " -r
    echo ""
    if [[ $REPLY == "yes" ]]; then
        echo "🗑️  Deleting namespace 'tak'..."
        kubectl delete namespace tak
        echo "✅ Namespace deleted. All resources and data removed."
        echo ""
        echo "🚀 To redeploy, run: ./scripts/deploy.sh"
    else
        echo "❌ Reset cancelled"
        exit 1
    fi
else
    echo "🔄 SOFT RESET: Restarting pods (keeping data)"
    echo ""
    
    echo "🔄 Restarting deployments..."
    kubectl -n tak rollout restart deployment/opentakserver || true
    kubectl -n tak rollout restart deployment/postgres || true
    kubectl -n tak rollout restart deployment/rabbitmq || true
    
    echo "✅ Deployments restarted"
    echo ""
    echo "📊 Current status:"
    kubectl -n tak get pods
    echo ""
    echo "💡 Tip: For a complete clean slate, use: ./scripts/reset.sh --hard"
fi

echo ""
