#!/bin/bash
# Setup SSH keys for passwordless authentication across cluster nodes
# This enables automated management of multi-node clusters

set -e

echo "========================================"
echo "  SSH Key Setup for Cluster Nodes"
echo "========================================"
echo ""

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "No SSH key found. Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "$(whoami)@$(hostname)"
    echo "✓ SSH key generated"
else
    echo "✓ SSH key already exists at ~/.ssh/id_rsa"
fi

echo ""
echo "Detecting cluster nodes..."

# Get list of all nodes
NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
CURRENT_NODE_IP=$(hostname -I | awk '{print $1}')

echo "Found nodes: $NODES"
echo "Current node: $CURRENT_NODE_IP"
echo ""

# Copy SSH key to each node
for ip in $NODES; do
    # Skip current node
    if [ "$ip" = "$CURRENT_NODE_IP" ]; then
        echo "⊘ Skipping current node ($ip)"
        continue
    fi
    
    echo "→ Configuring $ip..."
    
    # Check if already configured
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no $ip "echo ok" &>/dev/null; then
        echo "  ✓ Already configured (passwordless SSH working)"
    else
        echo "  Copying SSH key (you'll need to enter password)..."
        ssh-copy-id -o StrictHostKeyChecking=no $ip
        
        # Verify it works
        if ssh -o ConnectTimeout=5 -o BatchMode=yes $ip "echo ok" &>/dev/null; then
            echo "  ✓ SSH key configured successfully"
        else
            echo "  ✗ Failed to configure SSH key"
        fi
    fi
done

echo ""
echo "========================================"
echo "  ✓ SSH Key Setup Complete!"
echo "========================================"
echo ""
echo "You can now run commands across nodes without passwords:"
echo "  for ip in $NODES; do ssh \$ip 'hostname'; done"
echo ""
