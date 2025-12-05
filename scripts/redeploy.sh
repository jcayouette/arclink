#!/bin/bash
# Complete Reset and Redeploy Script
# Performs hard reset and full redeployment from scratch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  OpenTAKServer Full Redeploy"
echo "========================================"
echo ""
echo "This will:"
echo "  1. Delete entire 'tak' namespace (all data lost)"
echo "  2. Wait for cleanup to complete"
echo "  3. Deploy fresh installation"
echo ""
echo "⚠️  WARNING: All PostgreSQL data will be permanently deleted!"
echo ""
read -p "Continue with full redeploy? (yes/no): " -r
echo ""

if [[ $REPLY != "yes" ]]; then
    echo "❌ Redeploy cancelled"
    exit 1
fi

# Step 1: Hard reset
echo "========================================"
echo "  Step 1: Cleanup"
echo "========================================"
echo ""

if kubectl get namespace tak &> /dev/null; then
    echo "🗑️  Deleting namespace 'tak'..."
    kubectl delete namespace tak
    
    # Wait for namespace to be fully deleted
    echo "⏳ Waiting for namespace deletion..."
    while kubectl get namespace tak &> /dev/null; do
        sleep 2
    done
    echo "✅ Namespace deleted"
else
    echo "ℹ️  Namespace 'tak' doesn't exist, skipping cleanup"
fi

echo ""

# Step 2: Configuration (skip if already configured)
echo "========================================"
echo "  Step 2: Configuration"
echo "========================================"
echo ""

# Check if already configured
if [ -f "$(dirname "$SCRIPT_DIR")/config.env" ]; then
    echo "✓ Configuration already exists, skipping configure.sh"
    echo "  (Delete config.env to reconfigure)"
else
    echo "🔧 Running configuration (auto-generating secrets and setting up registry)..."
    echo ""
    # Run configure script
    "$SCRIPT_DIR/configure.sh"
fi

echo ""

# Step 3: Build Docker images
echo "========================================"
echo "  Step 3: Build Docker Images"
echo "========================================"
echo ""
echo "🏗️  Building custom images (this may take ~30 minutes on first run)..."
echo ""

# Navigate to docker directory and run setup
cd "$(dirname "$SCRIPT_DIR")/docker"
./setup.sh

echo ""

# Step 4: Verify Registry and Distribute Configuration
echo "========================================"
echo "  Step 4: Verify Registry & Distribute Config"
echo "========================================"
echo ""
echo "⏳ Waiting for Docker registry to be fully ready..."

# Give registry a moment to stabilize
sleep 5

# Test registry connectivity
MAX_WAIT=60
ELAPSED=0
REGISTRY_READY=false

# Load registry address from config
source "$(dirname "$SCRIPT_DIR")/config.env" 2>/dev/null || REGISTRY_ADDRESS="localhost:5000"

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -s "http://${REGISTRY_ADDRESS}/v2/_catalog" >/dev/null 2>&1; then
        REGISTRY_READY=true
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ "$REGISTRY_READY" = true ]; then
    echo "✅ Docker registry is ready"
    echo "   Available images:"
    curl -s "http://${REGISTRY_ADDRESS}/v2/_catalog" | grep -o '"repositories":\[.*\]' || echo "   (checking...)"
else
    echo "⚠️  Registry not responding, but continuing with deployment"
fi

# Distribute registry configuration to all agent nodes
echo ""
echo "📡 Distributing registry configuration to agent nodes..."

# Get list of agent node IPs
AGENT_IPS=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/master!="true")].status.addresses[?(@.type=="InternalIP")].address}')
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ -n "$AGENT_IPS" ]; then
    for ip in $AGENT_IPS; do
        # Skip if it's the current node
        if [ "$ip" = "$CURRENT_IP" ]; then
            continue
        fi
        
        echo "   → Configuring $ip..."
        
        # Check if SSH is configured
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no $ip "echo ok" &>/dev/null; then
            echo "   ⚠️  Passwordless SSH not configured for $ip"
            echo "   Run: ./scripts/helpers/setup-ssh-keys.sh"
            continue
        fi
        
        # Copy registries.yaml
        if scp -q /etc/rancher/k3s/registries.yaml $ip:/tmp/registries.yaml 2>/dev/null; then
            ssh $ip "sudo mkdir -p /etc/rancher/k3s && sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml" 2>/dev/null
            
            # Restart appropriate k3s service
            if ssh $ip "sudo systemctl is-active --quiet k3s-agent" 2>/dev/null; then
                ssh $ip "sudo systemctl restart k3s-agent" 2>/dev/null
            elif ssh $ip "sudo systemctl is-active --quiet k3s" 2>/dev/null; then
                ssh $ip "sudo systemctl restart k3s" 2>/dev/null
            fi
            
            echo "   ✓ $ip configured"
        else
            echo "   ✗ Failed to copy to $ip"
        fi
    done
else
    echo "   ℹ️  No agent nodes detected (single-node cluster)"
fi

# Restart K3s master to ensure registry configuration is loaded
echo ""
echo "🔄 Restarting K3s master..."
if sudo systemctl is-active --quiet k3s; then
    sudo systemctl restart k3s
    echo "✅ K3s server restarted"
elif sudo systemctl is-active --quiet k3s-agent; then
    sudo systemctl restart k3s-agent
    echo "✅ K3s agent restarted"
fi

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
sleep 5
kubectl wait --for=condition=Ready nodes --all --timeout=60s
echo "✅ Cluster is ready"

echo ""

# Step 5: Deploy to Kubernetes
echo "========================================"
echo "  Step 5: Deploy to Kubernetes"
echo "========================================"
echo ""
echo "🚀 Starting deployment..."
echo ""

# Navigate back to root and run deploy script
cd "$(dirname "$SCRIPT_DIR")"
"$SCRIPT_DIR/deploy.sh"

echo ""
echo "========================================"
echo "  🎉 Redeploy Complete!"
echo "========================================"
echo ""
echo "Your OpenTAKServer has been completely redeployed"
echo "with fresh images, database, and default settings."
echo ""
