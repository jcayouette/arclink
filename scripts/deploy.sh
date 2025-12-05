#!/bin/bash
# OpenTAK Server Deployment Script
# Deploys PostgreSQL, RabbitMQ, and OpenTAKServer to k3s

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")/manifests"

echo "========================================"
echo "  OpenTAK Server Deployment"
echo "========================================"
echo ""

# Create namespace
echo "🔧 Creating tak namespace..."
kubectl create namespace tak --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Deploy PostgreSQL
echo "🐘 Deploying PostgreSQL..."
kubectl apply -f "$MANIFEST_DIR/postgres.yaml"
echo "✅ PostgreSQL manifests applied"
echo ""

# Deploy RabbitMQ
echo "🐰 Deploying RabbitMQ..."
kubectl apply -f "$MANIFEST_DIR/rabbitmq.yaml"
echo "✅ RabbitMQ manifests applied"
echo ""

# Deploy nginx config
echo "🔧 Deploying nginx configuration..."
kubectl apply -f "$MANIFEST_DIR/nginx-config.yaml"
echo "✅ Nginx config applied"
echo ""

# Wait for dependencies
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl -n tak wait --for=condition=ready pod -l app=postgres --timeout=120s
echo "✅ PostgreSQL is ready"
echo ""

echo "⏳ Waiting for RabbitMQ to be ready..."
kubectl -n tak wait --for=condition=ready pod -l app=rabbitmq --timeout=120s
echo "✅ RabbitMQ is ready"
echo ""

# Deploy OpenTAKServer
echo "🚀 Deploying OpenTAKServer..."
kubectl apply -f "$MANIFEST_DIR/ots-with-ui-custom-images.yaml"
echo "✅ OpenTAKServer manifests applied"
echo ""

# Function to show animated dots
show_waiting() {
    local msg="$1"
    local dots=""
    for i in {1..3}; do
        printf "\r${msg}${dots}   "
        dots="${dots}."
        sleep 0.5
    done
}

echo "========================================"
echo "  Waiting for Deployment"
echo "========================================"
echo ""

# Wait for pod to be created
echo "⏳ Waiting for OpenTAKServer pod to start..."
sleep 2

# Wait for pod to be running (with animated progress)
MAX_WAIT=300  # 5 minutes
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    POD_STATUS=$(kubectl -n tak get pods -l app=opentakserver -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    
    if [ "$POD_STATUS" = "Running" ]; then
        break
    fi
    
    # Show progress with dots
    show_waiting "   Pod initializing"
    
    ELAPSED=$((ELAPSED + 2))
done

if [ "$POD_STATUS" != "Running" ]; then
    echo ""
    echo "❌ Pod did not start within 5 minutes"
    kubectl -n tak get pods -l app=opentakserver
    exit 1
fi

echo ""
echo "✅ Pod is running, waiting for services to be ready..."
echo ""

# Wait for API to be healthy
echo "⏳ Checking API health endpoint..."
source "$(dirname "$SCRIPT_DIR")/config.env" 2>/dev/null || PRIMARY_NODE_ADDRESS="localhost"
API_URL="http://${PRIMARY_NODE_ADDRESS}:${WEB_NODEPORT:-31080}/api/health"

MAX_WAIT=180  # 3 minutes for API
ELAPSED=0
API_READY=false

while [ $ELAPSED -lt $MAX_WAIT ]; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL" 2>/dev/null || echo "000")
    
    if [ "$HTTP_STATUS" = "200" ]; then
        API_READY=true
        break
    fi
    
    show_waiting "   Waiting for API"
    ELAPSED=$((ELAPSED + 2))
done

echo ""

if [ "$API_READY" = false ]; then
    echo "⚠️  API not responding yet, but pod is running"
    echo "   This is normal - services may take a few more minutes"
    echo ""
fi

# Run comprehensive health checks
echo "========================================"
echo "  🎉 Deployment Health Check"
echo "========================================"
echo ""

# Check pods
echo "📦 Pod Status:"
kubectl -n tak get pods -l app=opentakserver
echo ""

# Check services
echo "🌐 Services:"
kubectl -n tak get svc opentakserver
echo ""

# Test endpoints
echo "🔍 Endpoint Tests:"

# Web UI
UI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${PRIMARY_NODE_ADDRESS}:${WEB_NODEPORT:-31080}/" 2>/dev/null || echo "000")
if [ "$UI_STATUS" = "200" ]; then
    echo "   ✅ Web UI: HTTP $UI_STATUS"
else
    echo "   ⏳ Web UI: HTTP $UI_STATUS (still starting)"
fi

# API Health
API_RESPONSE=$(curl -s "$API_URL" 2>/dev/null || echo '{"status":"unavailable"}')
if echo "$API_RESPONSE" | grep -q "healthy"; then
    echo "   ✅ API Health: healthy"
else
    echo "   ⏳ API Health: starting"
fi

# API Auth (should redirect)
AUTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${PRIMARY_NODE_ADDRESS}:${WEB_NODEPORT:-31080}/api/data_packages" 2>/dev/null || echo "000")
if [ "$AUTH_STATUS" = "302" ]; then
    echo "   ✅ Authentication: working (redirect to login)"
elif [ "$AUTH_STATUS" = "401" ]; then
    echo "   ✅ Authentication: working (unauthorized)"
else
    echo "   ⏳ Authentication: HTTP $AUTH_STATUS"
fi

echo ""
echo "========================================"
echo "  🚀 Deployment Complete!"
echo "========================================"
echo ""
echo "📍 Access your OpenTAKServer:"
echo "   🌐 Web UI:  http://${PRIMARY_NODE_ADDRESS}:${WEB_NODEPORT:-31080}"
echo "   👤 Username: administrator"
echo "   🔑 Password: password (change immediately!)"
echo ""
echo "📡 TAK Client Connections:"
echo "   TCP CoT: ${PRIMARY_NODE_ADDRESS}:${TCP_COT_NODEPORT:-31088}"
echo "   SSL CoT: ${PRIMARY_NODE_ADDRESS}:${SSL_COT_NODEPORT:-31089}"
echo ""
echo "🔧 Management Commands:"
echo "   Status:   ./scripts/helpers/status.sh"
echo "   Logs:     ./scripts/helpers/logs.sh"
echo "   Password: ./scripts/helpers/set-admin-password.sh"
echo "   Redeploy: ./scripts/redeploy.sh"
echo ""

if [ "$API_READY" = true ]; then
    echo "✨ All systems operational!"
else
    echo "⏳ Services are starting - check status in a few minutes"
    echo "   Run: ./scripts/status.sh"
fi

echo ""
