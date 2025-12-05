#!/bin/bash
# Quick Longhorn deployment with monitoring
# Usage: ./deploy-longhorn-monitored.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")/ansible"

# Set kubeconfig
export KUBECONFIG="$ANSIBLE_DIR/kubeconfig"

echo "========================================"
echo "Longhorn Deployment with Monitoring"
echo "========================================"
echo ""
echo "This will:"
echo "  1. Wipe existing Longhorn data"
echo "  2. Deploy Longhorn with /mnt/longhorn"
echo "  3. Show real-time progress"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Check if in tmux or screen
if [ -n "$TMUX" ] || [ -n "$STY" ]; then
    USE_SPLIT=true
else
    USE_SPLIT=false
fi

echo ""
echo "Step 1: Wiping Longhorn disks..."
echo "========================================"
cd "$ANSIBLE_DIR"
ansible-playbook -i inventory/production.yml playbooks/wipe-longhorn-disks.yml

echo ""
echo "Step 2: Deploying Longhorn..."
echo "========================================"

if [ "$USE_SPLIT" = true ]; then
    echo "Detected tmux/screen. Starting monitoring in split pane..."
    if [ -n "$TMUX" ]; then
        tmux split-window -h "$SCRIPT_DIR/helpers/monitor-longhorn.sh"
        tmux select-pane -t 0
    fi
fi

ansible-playbook -i inventory/production.yml playbooks/deploy-longhorn.yml

echo ""
echo "========================================"
echo "Deployment complete!"
echo "========================================"
echo ""
echo "To monitor Longhorn:"
echo "  Dashboard: $SCRIPT_DIR/helpers/monitor-longhorn.sh"
echo "  Logs: $SCRIPT_DIR/helpers/stream-longhorn-logs.sh manager"
echo ""
echo "To access UI:"
nodeport=$(kubectl get svc longhorn-frontend-nodeport -n longhorn-system -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
echo "  http://10.0.0.160:$nodeport"
echo ""
