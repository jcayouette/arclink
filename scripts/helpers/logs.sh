#!/bin/bash
# OpenTAK Server Logs Viewer
# View logs from various components

set -e

# Check if namespace exists
if ! kubectl get namespace tak &> /dev/null; then
    echo "❌ Namespace 'tak' does not exist. Nothing to show."
    exit 1
fi

# Function to display menu
show_menu() {
    echo "========================================"
    echo "  OpenTAK Server Logs"
    echo "========================================"
    echo ""
    echo "Select component to view logs:"
    echo ""
    echo "  1) OpenTAKServer (main application)"
    echo "  2) OpenTAKServer (nginx proxy)"
    echo "  3) OpenTAKServer (setup init container)"
    echo "  4) OpenTAKServer (build-ui init container)"
    echo "  5) PostgreSQL"
    echo "  6) RabbitMQ"
    echo "  7) All pods (overview)"
    echo "  0) Exit"
    echo ""
}

# Function to get pod name
get_ots_pod() {
    kubectl -n tak get pods -l app=opentakserver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Parse command line argument for direct access
if [[ -n "$1" ]]; then
    case "$1" in
        ots|opentakserver)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                exit 1
            fi
            echo "📋 Following OpenTAKServer logs (Ctrl+C to exit)..."
            kubectl -n tak logs -f "$POD" -c ots
            exit 0
            ;;
        nginx)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                exit 1
            fi
            echo "📋 Following nginx logs (Ctrl+C to exit)..."
            kubectl -n tak logs -f "$POD" -c nginx
            exit 0
            ;;
        setup|init)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                exit 1
            fi
            echo "📋 Viewing setup-ots init container logs..."
            kubectl -n tak logs "$POD" -c setup-ots 2>&1 || echo "Init container may have completed or not started yet"
            exit 0
            ;;
        ui|build-ui)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                exit 1
            fi
            echo "📋 Following build-ui init container logs (Ctrl+C to exit)..."
            kubectl -n tak logs -f "$POD" -c build-ui 2>&1 || echo "Init container may have completed or not started yet"
            exit 0
            ;;
        postgres|postgresql)
            echo "📋 Following PostgreSQL logs (Ctrl+C to exit)..."
            kubectl -n tak logs -f deployment/postgres
            exit 0
            ;;
        rabbitmq|rabbit)
            echo "📋 Following RabbitMQ logs (Ctrl+C to exit)..."
            kubectl -n tak logs -f deployment/rabbitmq
            exit 0
            ;;
    esac
fi

# Interactive menu
while true; do
    show_menu
    read -p "Enter choice [0-7]: " choice
    echo ""
    
    case $choice in
        1)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                echo ""
                read -p "Press Enter to continue..."
                continue
            fi
            echo "📋 Following OpenTAKServer logs (Ctrl+C to return)..."
            kubectl -n tak logs -f "$POD" -c ots || true
            echo ""
            ;;
        2)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                echo ""
                read -p "Press Enter to continue..."
                continue
            fi
            echo "📋 Following nginx logs (Ctrl+C to return)..."
            kubectl -n tak logs -f "$POD" -c nginx || true
            echo ""
            ;;
        3)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                echo ""
                read -p "Press Enter to continue..."
                continue
            fi
            echo "📋 Viewing setup-ots init container logs..."
            kubectl -n tak logs "$POD" -c setup-ots --tail=50 2>&1 || echo "Init container may have completed or not started yet"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        4)
            POD=$(get_ots_pod)
            if [[ -z "$POD" ]]; then
                echo "❌ No OpenTAKServer pod found"
                echo ""
                read -p "Press Enter to continue..."
                continue
            fi
            echo "📋 Following build-ui init container logs (Ctrl+C to return)..."
            kubectl -n tak logs -f "$POD" -c build-ui 2>&1 || echo "Init container may have completed or not started yet"
            echo ""
            ;;
        5)
            echo "📋 Following PostgreSQL logs (Ctrl+C to return)..."
            kubectl -n tak logs -f deployment/postgres || true
            echo ""
            ;;
        6)
            echo "📋 Following RabbitMQ logs (Ctrl+C to return)..."
            kubectl -n tak logs -f deployment/rabbitmq || true
            echo ""
            ;;
        7)
            echo "📊 Pod Overview:"
            kubectl -n tak get pods
            echo ""
            echo "Recent events:"
            kubectl -n tak get events --sort-by='.lastTimestamp' | tail -20
            echo ""
            read -p "Press Enter to continue..."
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please select 0-7"
            echo ""
            read -p "Press Enter to continue..."
            ;;
    esac
done
