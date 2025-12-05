#!/bin/bash
# Configuration script for OpenTAKServer K3s deployment
# This script helps customize the deployment for your environment

set -e

echo "======================================"
echo "OpenTAKServer K3s Configuration"
echo "======================================"
echo

# Check if config.env already exists
if [ -f config.env ]; then
    echo "Found existing config.env"
    read -p "Do you want to reconfigure? (y/n): " reconfigure
    if [ "$reconfigure" != "y" ]; then
        echo "Using existing configuration"
        exit 0
    fi
fi

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "ERROR: docker not found. Please install Docker first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to K3s cluster. Is K3s running?"
    exit 1
fi

echo "✓ kubectl found"
echo "✓ docker found"
echo "✓ K3s cluster accessible"
echo

# Get primary node address (IP or DNS name)
echo "Step 1: Network Configuration"
echo "------------------------------"
DEFAULT_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
DEFAULT_HOSTNAME=$(hostname -f 2>/dev/null || hostname)
echo "You can use either an IP address or DNS hostname"
echo "Examples: 10.0.0.160 or node0.research.core"
read -p "Enter primary node address [$DEFAULT_HOSTNAME]: " PRIMARY_NODE_ADDRESS
PRIMARY_NODE_ADDRESS=${PRIMARY_NODE_ADDRESS:-$DEFAULT_HOSTNAME}

# Registry address
REGISTRY_ADDRESS="${PRIMARY_NODE_ADDRESS}:5000"
echo "Registry will be: $REGISTRY_ADDRESS"

# NodePorts
echo
echo "Step 2: Port Configuration"
echo "---------------------------"
echo "NodePorts must be between 30000-32767"
read -p "Web UI port [31080]: " WEB_NODEPORT
WEB_NODEPORT=${WEB_NODEPORT:-31080}

read -p "TCP CoT port [31088]: " TCP_COT_NODEPORT
TCP_COT_NODEPORT=${TCP_COT_NODEPORT:-31088}

read -p "SSL CoT port [31089]: " SSL_COT_NODEPORT
SSL_COT_NODEPORT=${SSL_COT_NODEPORT:-31089}

# Namespace
echo
echo "Step 3: Kubernetes Configuration"
echo "---------------------------------"
read -p "Namespace [tak]: " NAMESPACE
NAMESPACE=${NAMESPACE:-tak}

# OTS Version
read -p "OpenTAKServer version [1.6.3]: " OTS_VERSION
OTS_VERSION=${OTS_VERSION:-1.6.3}

# Security
echo
echo "Step 4: Credentials (CHANGE FOR PRODUCTION!)"
echo "---------------------------------------------"
read -p "PostgreSQL password [otspassword]: " POSTGRES_PASSWORD
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-otspassword}

read -p "PostgreSQL user [ots]: " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-ots}

read -p "RabbitMQ password [guest]: " RABBITMQ_PASSWORD
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-guest}

# Generate secrets
echo
echo "Generating random secrets..."
SECRET_KEY=$(openssl rand -hex 32)
SECURITY_PASSWORD_SALT=$(openssl rand -base64 32)

# Write config file
echo
echo "Writing configuration to config.env..."
cat > config.env <<EOF
# OpenTAKServer K3s Configuration
# Generated on $(date)

# Network
PRIMARY_NODE_ADDRESS=${PRIMARY_NODE_ADDRESS}
REGISTRY_ADDRESS=${REGISTRY_ADDRESS}

# Ports
WEB_NODEPORT=${WEB_NODEPORT}
TCP_COT_NODEPORT=${TCP_COT_NODEPORT}
SSL_COT_NODEPORT=${SSL_COT_NODEPORT}

# Kubernetes
NAMESPACE=${NAMESPACE}
OTS_VERSION=${OTS_VERSION}

# Database
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_DB=ots

# RabbitMQ
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}

# Flask Secrets (auto-generated)
SECRET_KEY=${SECRET_KEY}
SECURITY_PASSWORD_SALT=${SECURITY_PASSWORD_SALT}
EOF

chmod 600 config.env

echo
echo "Updating manifest files with your configuration..."
cp manifests/ots-with-ui-custom-images.yaml manifests/ots-with-ui-custom-images.yaml.bak 2>/dev/null || true

# Update registry address in manifest
sed -i "s|image: [0-9.]*:[0-9]*/|image: ${REGISTRY_ADDRESS}/|g" manifests/ots-with-ui-custom-images.yaml

# Update NodePorts
sed -i "s|nodePort: 31080|nodePort: ${WEB_NODEPORT}|g" manifests/ots-with-ui-custom-images.yaml
sed -i "s|nodePort: 31088|nodePort: ${TCP_COT_NODEPORT}|g" manifests/ots-with-ui-custom-images.yaml
sed -i "s|nodePort: 31089|nodePort: ${SSL_COT_NODEPORT}|g" manifests/ots-with-ui-custom-images.yaml

# Update database credentials
sed -i "s|POSTGRES_PASSWORD: otspassword|POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}|g" manifests/postgres.yaml
sed -i "s|value: \"otspassword\"|value: \"${POSTGRES_PASSWORD}\"|g" manifests/postgres.yaml
sed -i "s|POSTGRES_USER: ots|POSTGRES_USER: ${POSTGRES_USER}|g" manifests/postgres.yaml
sed -i "s|value: \"ots\"|value: \"${POSTGRES_USER}\"|g" manifests/postgres.yaml

# Update secrets in OTS manifest
sed -i "s|SECRET_KEY: .*|SECRET_KEY: ${SECRET_KEY}|g" manifests/ots-with-ui-custom-images.yaml
sed -i "s|SECURITY_PASSWORD_SALT: .*|SECURITY_PASSWORD_SALT: ${SECURITY_PASSWORD_SALT}|g" manifests/ots-with-ui-custom-images.yaml

echo
echo "======================================"
echo "Setting Up Docker Registry"
echo "======================================"
echo

# Check if registry is already running
if docker ps | grep -q "registry:2"; then
    echo "✓ Docker registry already running"
else
    echo "Starting Docker registry on port 5000 (HTTP)..."
    echo "Note: Using HTTP for simplicity. See INSTALL.md for HTTPS setup."
    docker run -d -p 5000:5000 --restart=always --name registry registry:2
    echo "✓ Docker registry started"
fi

# Configure Docker daemon for insecure HTTP registry
echo "Configuring Docker for insecure registry..."
if [ -f /etc/docker/daemon.json ]; then
    # Check if already configured
    if grep -q "${REGISTRY_ADDRESS}" /etc/docker/daemon.json; then
        echo "✓ Docker already configured for ${REGISTRY_ADDRESS}"
    else
        # Add to existing insecure-registries array
        sudo jq --arg reg "${REGISTRY_ADDRESS}" '.["insecure-registries"] += [$reg]' /etc/docker/daemon.json > /tmp/daemon.json.tmp
        sudo mv /tmp/daemon.json.tmp /etc/docker/daemon.json
        sudo systemctl restart docker
        sleep 3
        echo "✓ Docker configured for insecure registry"
    fi
else
    # Create new daemon.json
    echo "{\"insecure-registries\": [\"${REGISTRY_ADDRESS}\"]}" | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl restart docker
    sleep 3
    echo "✓ Docker configured for insecure registry"
fi

# Configure K3s to allow insecure registry
echo "Configuring K3s for insecure registry..."
sudo mkdir -p /etc/rancher/k3s

# Check if already configured with this exact registry
if grep -q "\"${REGISTRY_ADDRESS}\":" /etc/rancher/k3s/registries.yaml 2>/dev/null; then
    echo "✓ K3s already configured for registry ${REGISTRY_ADDRESS}"
else
    # If file exists, we need to add to it properly, otherwise create new
    if [ -f /etc/rancher/k3s/registries.yaml ]; then
        echo "Adding ${REGISTRY_ADDRESS} to existing registries.yaml..."
        # Backup existing file
        sudo cp /etc/rancher/k3s/registries.yaml /etc/rancher/k3s/registries.yaml.bak
        
        # Add new registry to mirrors section
        if grep -q "^mirrors:" /etc/rancher/k3s/registries.yaml; then
            # Append to existing mirrors
            sudo sed -i "/^mirrors:/a\\  \"${REGISTRY_ADDRESS}\":\n    endpoint:\n      - \"http://${REGISTRY_ADDRESS}\"" /etc/rancher/k3s/registries.yaml
        else
            # Create mirrors section
            echo "mirrors:" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "  \"${REGISTRY_ADDRESS}\":" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "    endpoint:" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "      - \"http://${REGISTRY_ADDRESS}\"" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
        fi
        
        # Add to configs section
        if grep -q "^configs:" /etc/rancher/k3s/registries.yaml; then
            # Append to existing configs
            sudo sed -i "/^configs:/a\\  \"${REGISTRY_ADDRESS}\":\n    tls:\n      insecure_skip_verify: true" /etc/rancher/k3s/registries.yaml
        else
            # Create configs section
            echo "" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "configs:" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "  \"${REGISTRY_ADDRESS}\":" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "    tls:" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
            echo "      insecure_skip_verify: true" | sudo tee -a /etc/rancher/k3s/registries.yaml > /dev/null
        fi
    else
        # Create new file
        cat <<EOF | sudo tee /etc/rancher/k3s/registries.yaml > /dev/null
mirrors:
  "${REGISTRY_ADDRESS}":
    endpoint:
      - "http://${REGISTRY_ADDRESS}"

configs:
  "${REGISTRY_ADDRESS}":
    tls:
      insecure_skip_verify: true
EOF
    fi
    
    echo "Restarting K3s to apply registry configuration..."
    if sudo systemctl is-active --quiet k3s; then
        sudo systemctl restart k3s
        echo "✓ K3s server restarted"
    elif sudo systemctl is-active --quiet k3s-agent; then
        sudo systemctl restart k3s-agent
        echo "✓ K3s agent restarted"
    fi
    
    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    sleep 5
    kubectl wait --for=condition=Ready nodes --all --timeout=60s
fi

echo
echo "======================================"
echo "Configuration Complete!"
echo "======================================"
echo
echo "✓ Configuration saved to: config.env"
echo "✓ Manifests updated with your settings"
echo "✓ Docker registry running at ${REGISTRY_ADDRESS}"
echo "✓ K3s configured for insecure registry"
echo

# Check if multi-node cluster
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODE_COUNT" -gt 1 ]; then
    echo "⚠️  IMPORTANT: Multi-Node Cluster Detected (${NODE_COUNT} nodes)"
    echo "   Registry configuration applied to master node only."
    echo ""
    echo "   For agent nodes, you have two options:"
    echo ""
    echo "   Option 1: Automatic (requires passwordless SSH):"
    read -p "   Do you want to automatically configure agent nodes now? (y/n): " AUTO_CONFIGURE
    
    if [ "$AUTO_CONFIGURE" = "y" ]; then
        echo ""
        echo "   Getting list of agent nodes..."
        AGENT_NODES=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/master!="true")].metadata.name}')
        
        echo "   Configuring agent nodes: $AGENT_NODES"
        for node in $AGENT_NODES; do
            echo "   → Configuring $node..."
            if scp -o ConnectTimeout=5 /etc/rancher/k3s/registries.yaml ${node}:/tmp/registries.yaml 2>/dev/null; then
                ssh -o ConnectTimeout=5 ${node} "sudo mkdir -p /etc/rancher/k3s && sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml && sudo systemctl restart k3s-agent" 2>/dev/null
                echo "   ✓ $node configured"
            else
                echo "   ✗ $node failed (may need password or SSH keys)"
            fi
        done
    else
        echo ""
        echo "   Option 2: Manual configuration:"
        echo "   Run this command to configure all agent nodes:"
        echo ""
        AGENT_NODES=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/master!="true")].metadata.name}' | tr ' ' '\n' | paste -sd ' ')
        echo "   for node in $AGENT_NODES; do"
        echo "     scp /etc/rancher/k3s/registries.yaml \$node:/tmp/registries.yaml"
        echo "     ssh \$node \"sudo mkdir -p /etc/rancher/k3s && sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml\""
        echo "     ssh \$node \"sudo systemctl restart k3s-agent\""
        echo "   done"
    fi
    echo ""
fi

echo "Next steps:"
if [ "$NODE_COUNT" -gt 1 ] && [ "$AUTO_CONFIGURE" != "y" ]; then
    echo "1. Configure agent nodes (see above)"
    echo "2. Build images: cd docker && ./setup.sh"
    echo "3. Deploy: ./scripts/deploy.sh"
else
    echo "1. Build images: cd docker && ./setup.sh"
    echo "2. Deploy: ./scripts/deploy.sh"
fi
echo
echo "Access after deployment:"
echo "  Web UI: http://${PRIMARY_NODE_ADDRESS}:${WEB_NODEPORT}"
echo "  Username: administrator"
echo "  Password: password (change immediately!)"
echo
