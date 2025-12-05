#!/bin/bash
# OpenTAK Server Status Monitor
# Shows deployment status and provides quick diagnostics

set -e

# Check if namespace exists
if ! kubectl get namespace tak &> /dev/null; then
    echo "❌ Namespace 'tak' does not exist. Run ./scripts/deploy.sh first."
    exit 1
fi

# Parse command line argument for watch mode
WATCH_MODE=false
if [[ "$1" == "-w" || "$1" == "--watch" ]]; then
    WATCH_MODE=true
fi

show_status() {
    clear
    echo "========================================"
    echo "  OpenTAK Server Status"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo ""
    
    # Get pod status
    echo "📦 Pod Status:"
    echo "----------------------------------------"
    kubectl -n tak get pods -o wide
    echo ""
    
    # Get services
    echo "🌐 Services:"
    echo "----------------------------------------"
    kubectl -n tak get svc
    echo ""
    
    # Get PVCs
    echo "💾 Storage:"
    echo "----------------------------------------"
    kubectl -n tak get pvc
    echo ""
    
    # Check for issues
    echo "🔍 Quick Diagnostics:"
    echo "----------------------------------------"
    
    # Check if pods are running
    RUNNING=$(kubectl -n tak get pods --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    TOTAL=$(kubectl -n tak get pods --no-headers 2>/dev/null | wc -l)
    
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo "✅ All pods are running ($RUNNING/$TOTAL)"
    else
        echo "⚠️  $RUNNING/$TOTAL pods are running"
    fi
    
    # Check for errors in pods
    ERRORS=$(kubectl -n tak get pods --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
    if [ "$ERRORS" -gt 0 ]; then
        echo "❌ $ERRORS pod(s) in Failed state"
    fi
    
    # Check for pending pods
    PENDING=$(kubectl -n tak get pods --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    if [ "$PENDING" -gt 0 ]; then
        echo "⏳ $PENDING pod(s) in Pending state"
    fi
    
    # Check for pods with restarts
    RESTARTS=$(kubectl -n tak get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[*].restartCount}{"\n"}{end}' 2>/dev/null | awk '{sum+=$1} END {print sum}')
    if [ "$RESTARTS" -gt 0 ]; then
        echo "⚠️  Total container restarts: $RESTARTS"
    fi
    
    # Check init containers
    INIT_STATUS=$(kubectl -n tak get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.initContainerStatuses[*].state}{"\n"}{end}' 2>/dev/null | grep -v "map\[\]" || true)
    if [ -n "$INIT_STATUS" ]; then
        echo "🔧 Init containers still running (this is normal during deployment)"
    fi
    
    # Check if OTS is ready
    OTS_READY=$(kubectl -n tak get pods -l app=opentakserver -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$OTS_READY" == "True" ]; then
        echo "✅ OpenTAKServer is ready!"
        echo ""
        echo "🌐 Access web UI:"
        echo "   kubectl -n tak port-forward --address 0.0.0.0 svc/opentakserver 8080:8080"
        echo "   Then open: http://$(hostname -I | awk '{print $1}'):8080"
    fi
    
    echo ""
    
    if [ "$WATCH_MODE" = false ]; then
        echo "💡 Quick Commands:"
        echo "   View logs:     ./scripts/logs.sh"
        echo "   Watch status:  ./scripts/status.sh --watch"
        echo "   Soft reset:    ./scripts/reset.sh"
        echo "   Hard reset:    ./scripts/reset.sh --hard"
        echo ""
    else
        echo "👁️  Watching mode (Ctrl+C to exit)"
        echo ""
    fi
}

if [ "$WATCH_MODE" = true ]; then
    while true; do
        show_status
        sleep 5
    done
else
    show_status
fi
