---
sidebar_position: 1
---

# Configuration

Learn how to configure Arclink for your deployment environment. The configuration process is automated through the `configure.sh` script.

## Prerequisites

Before configuring Arclink, ensure you have:

- **K3s**: Installed and running on your cluster node(s)
- **kubectl**: Configured and connected to your K3s cluster  
- **Docker**: Installed on the machine where you'll build images
- **RAM**: At least 4GB free memory
- **Storage**: 20GB+ free disk space
- **Network**: Connectivity between all nodes (if multi-node cluster)

## Automated Configuration (Recommended)

From the repository root, run the interactive configuration wizard:

```bash
./scripts/configure.sh
```

The script will prompt you for:

1. **Primary Node Address**: IP or DNS name of your K3s primary node
2. **Registry Address**: Where to host the Docker registry (usually same as primary node)
3. **NodePorts**: Ports for external access (defaults: 31080, 31088, 31089)
4. **Namespace**: Kubernetes namespace (default: opentakserver)
5. **Admin Password**: Password for the OpenTAK Server admin user

### What It Does

The configuration script automatically:

1. **Generates Secure Secrets**
   - `SECRET_KEY`: Flask session encryption (64-char hex)
   - `SECURITY_PASSWORD_SALT`: Password hashing salt (64-char hex)
   - Uses cryptographically secure random generation

2. **Creates config.env**
   - Sets primary node and registry addresses
   - Configures NodePort assignments
   - Generates database and RabbitMQ passwords
   - Sets namespace and credentials

3. **Updates Manifests**
   - Replaces placeholders in YAML files
   - Sets image registry references
   - Injects credentials as base64-encoded secrets
   - Configures NodePort values

## Understanding config.env

The configuration file (`config.env`) drives the entire deployment. Here's what each section means:

### Network Settings

```bash
# Primary K3s node address (IP or DNS)
PRIMARY_NODE_ADDRESS=192.168.1.100

# Docker registry address for image distribution
# Format: <address>:5000
REGISTRY_ADDRESS=192.168.1.100:5000
```

- **PRIMARY_NODE_ADDRESS**: Where users access the TAK server (can be IP or DNS hostname)
- **REGISTRY_ADDRESS**: Where Docker images are stored (use IP for reliability)

### Kubernetes Settings

```bash
# Namespace for all OpenTAK components
NAMESPACE=opentakserver

# External access ports (must be 30000-32767)
NODEPORT_WEB_UI=31080    # Web interface
NODEPORT_TCP_COT=31088   # CoT TCP connection
NODEPORT_SSL_COT=31089   # CoT SSL connection
```

- **NAMESPACE**: Isolates OpenTAK resources from other cluster workloads
- **NodePorts**: Must be in Kubernetes range 30000-32767

### Application Credentials

```bash
# OpenTAK Server admin user password
OTS_ADMIN_PASSWORD=your_secure_password

# PostgreSQL database password
POSTGRES_PASSWORD=generated_random_password

# RabbitMQ message queue password
RABBITMQ_PASSWORD=generated_random_password
```

:::warning Security Warning
Change default passwords before production deployment! These credentials protect your TAK server and data.
:::

### Security Secrets

```bash
# Flask session encryption key (auto-generated)
SECRET_KEY=f3e4d5c6b7a89012...64chars...890abcdef12345678

# Password hashing salt (auto-generated)
SECURITY_PASSWORD_SALT=9876543210fedc...64chars...cba0987654321fedcba
```

These secrets are critical for security:
- **SECRET_KEY**: Encrypts session cookies. Must remain static or users will be logged out.
- **SECURITY_PASSWORD_SALT**: Used for password hashing. Never change after deployment.

:::danger Critical
Once set, these secrets must NEVER change or all user sessions and passwords will be invalidated!
:::

## Manual Configuration

If you prefer manual configuration or need customization beyond the wizard:

```bash
# Copy example configuration
cp config.env.example config.env

# Edit with your preferred editor
nano config.env

# Apply changes to manifests
./scripts/configure.sh --update-manifests-only
```

The `--update-manifests-only` flag applies your `config.env` values to the Kubernetes manifest files without prompting for input.

## Advanced Configuration

### Custom Storage Class

By default, Arclink uses `longhorn` for persistent storage. To use a different storage class:

**For PostgreSQL:**
```bash
# Edit postgres.yaml
nano manifests/postgres.yaml

# Change storageClassName
spec:
  storageClassName: local-path  # or your storage class
```

**For OpenTAK Server:**
```bash
# Edit main manifest
nano manifests/ots-with-ui-custom-images.yaml

# Update storageClassName in PersistentVolumeClaim
spec:
  storageClassName: local-path
```

### Using Domain Names

To use DNS names instead of IP addresses:

1. **Set domain in config.env:**
```bash
PRIMARY_NODE_ADDRESS=tak.example.com
REGISTRY_ADDRESS=192.168.1.100:5000  # Keep registry as IP
```

2. **Configure DNS A record:**
```text
tak.example.com → 192.168.1.100
```

3. **Update firewall** to allow NodePort traffic (31080, 31088, 31089)

**Why keep registry as IP?** DNS may not resolve during K3s startup, causing pod failures.

### Multi-Node Cluster Configuration

For clusters with multiple worker nodes:

1. **Use IP address for REGISTRY_ADDRESS** (DNS resolution issues during startup)
2. **Ensure registry accessible from all nodes** (check firewall rules for port 5000)
3. **K3s configured on all nodes** to trust insecure registry (handled automatically by deploy script)

**Example multi-node setup:**
```bash
# config.env for 3-node cluster
PRIMARY_NODE_ADDRESS=192.168.1.100  # Primary node
REGISTRY_ADDRESS=192.168.1.100:5000 # Registry on primary
# Worker nodes: 192.168.1.101, 192.168.1.102
```

### Custom NodePort Configuration

Default NodePort assignments:

| Service | Port | Purpose |
|---------|------|---------|
| Web UI | 31080 | HTTP web interface |
| TCP CoT | 31088 | CoT TCP streaming |
| SSL CoT | 31089 | CoT SSL streaming |

To change ports (must be 30000-32767):

1. **Update config.env:**
```bash
NODEPORT_WEB_UI=30080
NODEPORT_TCP_COT=30088
NODEPORT_SSL_COT=30089
```

2. **Re-run configuration:**
```bash
./scripts/configure.sh --update-manifests-only
```

## Storage Configuration

### Longhorn (Recommended)

For production deployments with high availability:

```yaml
storageClassName: longhorn
```

Benefits:
- Automatic replication
- Snapshot support
- Volume migration
- High availability

### Local Path (Development)

For single-node or development:

```yaml
storageClassName: local-path
```

Benefits:
- Simple setup
- Fast performance
- Low overhead

## Security Configuration

### Changing Default Password

After deployment, immediately change the admin password:

```bash
./scripts/helpers/set-admin-password.sh
```

### Certificate Management

OpenTAK Server generates its own CA and certificates. To issue client certificates:

1. Access web UI
2. Navigate to **Certificates**
3. Create new certificate for each device
4. Download and install on ATAK/iTAK devices

## Environment-Specific Settings

### Production

- Use Longhorn for storage
- Set strong passwords
- Use hostnames with proper DNS
- Enable monitoring
- Regular backups

### Development

- Local path storage acceptable
- Can use IP addresses
- Faster iteration
- Less resource overhead

### Air-Gapped

- Pre-pull all images
- Use IP addresses
- Local Docker registry essential
- No external dependencies

## Verifying Configuration

After running `configure.sh`, verify everything is correct:

```bash
# Check config.env exists and has all required variables
cat config.env

# Verify manifests were updated with your settings
grep "PRIMARY_NODE_ADDRESS" manifests/*.yaml
grep "REGISTRY_ADDRESS" manifests/*.yaml

# Check that secrets were properly encoded (after deployment)
kubectl get secret -n opentakserver opentakserver-secret -o yaml 2>/dev/null || echo "Not deployed yet"
```

## Troubleshooting Configuration

### Issue: configure.sh fails with "kubectl not found"

**Solution**: Install kubectl or ensure it's in your PATH
```bash
# Check kubectl installation
which kubectl

# Install kubectl if needed (Ubuntu/Debian)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Issue: Cannot connect to K3s cluster

**Solution**: Check K3s is running and kubeconfig is set
```bash
# Check K3s status
sudo systemctl status k3s

# Set kubeconfig if needed
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Or use sudo with kubectl
sudo kubectl get nodes
```

### Issue: Manifests not updating with config.env values

**Solution**: Ensure config.env has correct format (no spaces around `=`)
```bash
# Correct format
PRIMARY_NODE_ADDRESS=192.168.1.100

# Incorrect format (will fail)
PRIMARY_NODE_ADDRESS = 192.168.1.100
```

### Issue: Registry address not resolving

**Solution**: Use IP address instead of hostname for registry
```bash
# Use IP address for reliability
REGISTRY_ADDRESS=192.168.1.100:5000

# Avoid hostname (DNS issues during K3s startup)
# REGISTRY_ADDRESS=takserver.local:5000  # DON'T USE
```

## Configuration Best Practices

### For Production Deployments

- ✅ Use strong, unique passwords for all credentials
- ✅ Use DNS hostnames for PRIMARY_NODE_ADDRESS (easier for users)
- ✅ Use IP address for REGISTRY_ADDRESS (reliable during startup)
- ✅ Choose non-default NodePorts if 31080/31088/31089 are in use
- ✅ Use Longhorn storage class for high availability
- ✅ Document your configuration for disaster recovery

### For Development

- ✅ IP addresses acceptable for both settings
- ✅ Default passwords OK for local testing
- ✅ Local-path storage class for speed
- ✅ Standard NodePorts (31080, 31088, 31089)

### For Air-Gapped Networks

- ✅ Must use IP addresses (no external DNS)
- ✅ Local Docker registry is essential
- ✅ Pre-download all images before deployment
- ✅ Test network connectivity between all nodes

## Next Steps

After completing configuration, proceed to:
1. **[Setup Guide](./setup.md)** - Build Docker images and configure registry
2. **[Deployment Guide](./deploy.md)** - Deploy to your K3s cluster
