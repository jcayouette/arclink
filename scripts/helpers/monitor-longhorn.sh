#!/bin/bash
# Monitor Longhorn deployment in real-time
# Usage: ./monitor-longhorn.sh [namespace]

set -e

# Set kubeconfig if not already set
if [ -z "$KUBECONFIG" ]; then
    export KUBECONFIG="$(dirname "$(dirname "$0")")/ansible/kubeconfig"
fi

NAMESPACE="${1:-longhorn-system}"
REFRESH_INTERVAL=3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace $NAMESPACE does not exist"
    exit 1
fi

# Main monitoring loop
while true; do
    clear
    print_header "Longhorn Monitoring - $NAMESPACE"
    echo "Press Ctrl+C to exit | Refreshing every ${REFRESH_INTERVAL}s"
    echo ""
    
    # Pod Status
    echo -e "${BLUE}Pod Status:${NC}"
    echo "─────────────────────────────────────────"
    
    total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    running_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    pending_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Pending" || echo 0)
    failed_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -cE "Error|CrashLoopBackOff|ImagePullBackOff" || echo 0)
    
    echo "Total: $total_pods | Running: $running_pods | Pending: $pending_pods | Failed: $failed_pods"
    echo ""
    
    # Show pod details
    kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | while read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        ready=$(echo "$line" | awk '{print $2}')
        status=$(echo "$line" | awk '{print $3}')
        restarts=$(echo "$line" | awk '{print $4}')
        
        if [[ "$status" == "Running" ]]; then
            print_success "$name ($ready) - $restarts restarts"
        elif [[ "$status" == "Pending" ]]; then
            print_warning "$name ($status)"
        else
            print_error "$name ($status) - $restarts restarts"
        fi
    done
    
    echo ""
    
    # Node Status
    echo -e "${BLUE}Longhorn Nodes:${NC}"
    echo "─────────────────────────────────────────"
    
    if kubectl get nodes.longhorn.io -n "$NAMESPACE" &>/dev/null; then
        node_count=$(kubectl get nodes.longhorn.io -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
        echo "Registered nodes: $node_count"
        echo ""
        
        kubectl get nodes.longhorn.io -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
            .items[] | 
            "\(.metadata.name): \(
                if .status.conditions[]? | select(.type=="Ready") | .status == "True" 
                then "✓ Ready" 
                else "⚠ Not Ready" 
                end
            ) - \(.spec.disks | length) disk(s)"
        ' 2>/dev/null || kubectl get nodes.longhorn.io -n "$NAMESPACE" --no-headers | awk '{print $1 ": Status=" $2}'
    else
        print_warning "No Longhorn nodes registered yet"
    fi
    
    echo ""
    
    # Volume Status (if any exist)
    echo -e "${BLUE}Volumes:${NC}"
    echo "─────────────────────────────────────────"
    
    volume_count=$(kubectl get volumes.longhorn.io -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$volume_count" -gt 0 ]; then
        echo "Total volumes: $volume_count"
        kubectl get volumes.longhorn.io -n "$NAMESPACE" --no-headers 2>/dev/null | head -10 | while read -r line; do
            name=$(echo "$line" | awk '{print $1}')
            state=$(echo "$line" | awk '{print $2}')
            echo "  - $name: $state"
        done
        if [ "$volume_count" -gt 10 ]; then
            echo "  ... and $((volume_count - 10)) more"
        fi
    else
        echo "No volumes created yet"
    fi
    
    echo ""
    
    # Recent Events
    echo -e "${BLUE}Recent Events (last 5):${NC}"
    echo "─────────────────────────────────────────"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -5 | awk '{
        if (NR>1) {
            type=$2; 
            reason=$3; 
            message=$4;
            for(i=5;i<=NF;i++) message=message" "$i;
            if (type ~ /Warning|Error/) 
                printf "⚠ %s: %s\n", reason, message
            else 
                printf "• %s: %s\n", reason, message
        }
    }'
    
    echo ""
    echo "─────────────────────────────────────────"
    echo -e "${BLUE}Shortcuts:${NC}"
    echo "  View manager logs: kubectl logs -n $NAMESPACE -l app=longhorn-manager --tail=50"
    echo "  View all pods: kubectl get pods -n $NAMESPACE"
    echo "  Describe pod: kubectl describe pod <pod-name> -n $NAMESPACE"
    
    sleep "$REFRESH_INTERVAL"
done
