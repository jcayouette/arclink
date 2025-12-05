---
sidebar_position: 1
---

# Quick Start Guide

Get OpenTAKServer running on your K3s cluster in minutes with full automation.

:::tip Choose Your Approach
- **Ansible (Recommended):** Full automation from bare metal to running app
- **Manual Scripts:** More control, step-by-step deployment
:::

## Ansible Quick Start (Recommended)

Deploy everything automatically with Ansible playbooks.

### Prerequisites

#### Hardware & OS Requirements
- ✅ Ubuntu Server 24.04 LTS on all nodes
- ✅ Minimum 8GB RAM, 32GB storage per node
- ✅ SSH access to all cluster nodes

#### Control Node Setup (Your Workstation/WSL)

**Install Ansible:**

```bash
# Ubuntu/Debian (includes Ansible 2.16+)
sudo apt update
sudo apt install -y ansible sshpass

# Verify installation (should be 2.9+ or higher)
ansible --version
```

:::info
`sshpass` is required for the initial bootstrap step with `--ask-pass`. It's only needed once to set up SSH keys.
:::

**Install kubectl:**

```bash
# Option 1: Using snap (easiest)
sudo snap install kubectl --classic

# Option 2: Manual download
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### TL;DR - Complete Deployment

#### Fresh Installation (No Existing Cluster)

```bash
# Clone the repository (from your control node: WSL/workstation)
cd ~
git clone https://github.com/jcayouette/arclink.git
cd arclink/ansible

# IMPORTANT: Configure inventory FIRST with your node IPs and username
nano inventory/production.yml
# Update:
#   - ansible_user (must match username on all nodes)
#   - ansible_host for each node (IP addresses)
#   - Add/remove nodes as needed

# One-time setup (establishes SSH access and prepares systems)
ansible-playbook playbooks/bootstrap.yml --ask-pass
ansible-playbook playbooks/disable-password-auth.yml  # Security: disable password SSH (auto-verifies keys)
ansible-playbook playbooks/setup-common.yml

# Deploy infrastructure
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-rancher.yml   # Optional: Web UI for cluster management
ansible-playbook playbooks/deploy-longhorn.yml  # REQUIRED: Storage for apps (deploy after Rancher, before apps)
ansible-playbook playbooks/deploy-registry.yml

# Deploy OpenTAKServer with Socket.IO patches
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

#### Reset Existing Cluster and Redeploy

If you have an existing cluster and want to start fresh:

```bash
cd ~/arclink/ansible

# 1. Complete cluster reset (removes K3s, Docker, Rancher, Longhorn, all data)
ansible-playbook playbooks/reset-cluster.yml
# Type 'yes' when prompted - THIS DESTROYS EVERYTHING!

# 2. Re-run setup to reconfigure systems
ansible-playbook playbooks/setup-common.yml

# 3. Deploy infrastructure from scratch
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-rancher.yml   # Optional: Web UI for cluster management
ansible-playbook playbooks/deploy-longhorn.yml  # REQUIRED: Storage for apps (deploy after Rancher, before apps)
ansible-playbook playbooks/deploy-registry.yml

# 4. Deploy OpenTAKServer
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

:::warning Reset Cluster
`reset-cluster.yml` completely removes:
- K3s cluster and all configurations
- Docker and all containers/images
- Longhorn storage and all volumes
- Rancher (if deployed)
- All application data and persistent volumes
- Network configurations and iptables rules

System configurations (kernel modules, /etc/hosts) are preserved but should be verified.
:::

**Total Time:** ~45 minutes (first run), ~15 minutes (subsequent)

**Access:** `http://node0:31080` or `http://your-node-ip:31080`

**Default Credentials:**
- Username: `administrator`
- Password: `password` (change immediately!)

### Step-by-Step with Ansible

#### 1. Configure Inventory

**⚠️ Do this FIRST before running any playbooks!**

```bash
cd ~/arclink/ansible
nano inventory/production.yml
```

**What to update in `inventory/production.yml`:**
1. **`ansible_user`** - Username that exists on all cluster nodes (must have sudo access)
2. **`ansible_host`** - IP address for each node
3. **Node names** - Match your actual hostnames or use simple names (node0, node1, etc.)
4. **`registry_host`** - Hostname or IP of your first master node

**Understanding the structure:**
- **`k3s_master`** - Control plane nodes (manage the cluster, run K3s server)
  - Single node: 1 master for testing/development
  - HA cluster: 3 masters for high availability with embedded etcd
  - First master has `k3s_master_primary: true`
- **`k3s_agents`** - Worker nodes (run your applications and workloads)
  - Optional: Can have 0 agents (master runs everything)
  - Recommended: 2+ agents for production workloads

---

**Example 1: Single Node (Basic Setup)**

Perfect for testing, development, or small deployments.

```yaml
all:
  vars:
    ansible_user: myuser              # ← Your SSH username
    ansible_become: yes
    registry_host: node0              # ← Master node
    registry_port: 5000
    ots_version: "1.6.3"
    
  children:
    k3s_cluster:
      children:
        # Single master runs everything
        k3s_master:
          hosts:
            node0:
              ansible_host: 192.168.1.100
              k3s_master_primary: true
        # No agents section needed for single node!
```

---

**Example 2: High Availability (3 Masters)**

Provides HA control plane with embedded etcd quorum. Masters also run workloads.

```yaml
all:
  vars:
    ansible_user: myuser
    ansible_become: yes
    registry_host: node0
    registry_port: 5000
    ots_version: "1.6.3"
    
  children:
    k3s_cluster:
      children:
        # HA Control Plane (3 Masters with embedded etcd)
        k3s_master:
          hosts:
            node0:
              ansible_host: 192.168.1.100
              k3s_master_primary: true  # First master initializes etcd
            node1:
              ansible_host: 192.168.1.101  # Master 2
            node2:
              ansible_host: 192.168.1.102  # Master 3
        # No agents - masters run workloads
```

---

**Example 3: Enterprise (3 Masters + Multiple Workers)**

Best for production: HA control plane with dedicated worker nodes.

```yaml
all:
  vars:
    ansible_user: myuser
    ansible_become: yes
    registry_host: node0
    registry_port: 5000
    ots_version: "1.6.3"
    
  children:
    k3s_cluster:
      children:
        # HA Control Plane (3 Masters)
        k3s_master:
          hosts:
            node0:
              ansible_host: 192.168.1.100
              k3s_master_primary: true  # First master
            node1:
              ansible_host: 192.168.1.101  # Master 2
            node2:
              ansible_host: 192.168.1.102  # Master 3
        
        # Dedicated Worker Nodes
        k3s_agents:
          hosts:
            node3:
              ansible_host: 192.168.1.103
            node4:
              ansible_host: 192.168.1.104
            node5:
              ansible_host: 192.168.1.105
            node6:
              ansible_host: 192.168.1.106
            # Add more workers as needed...
```

---

#### 2. Bootstrap SSH Access

```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

Enables passwordless SSH for all future commands.

**What this does:**
- Generates SSH key on your control node (if not present)
- Distributes your SSH public key to all cluster nodes
- Tests passwordless SSH connectivity
- Required before running any other playbooks

:::info Learn More
See [Bootstrap SSH Access](./ansible/bootstrap-ssh.md) for detailed setup, troubleshooting, and security considerations.
:::

#### 3. Disable Password Authentication (Security)

```bash
ansible-playbook playbooks/disable-password-auth.yml
```

**Critical security step!** Disables SSH password authentication on all nodes.

**What this does:**
- **Automatically verifies** SSH keys work on ALL nodes first
- Fails with clear instructions if any node is unreachable
- Disables password-based SSH login
- Only SSH key authentication works after this
- Protects against brute-force attacks
- Implements production security best practice

**If verification fails:**

The playbook will stop and tell you to re-run bootstrap:

```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

:::danger Keep Your SSH Key Safe
After this step, you MUST use SSH keys. Back up `~/.ssh/id_ed25519` to a secure location!
:::

#### 4. Prepare Systems

```bash
ansible-playbook playbooks/setup-common.yml
```

Installs packages, loads kernel modules, configures system settings.

#### 5. Deploy K3s Cluster

```bash
ansible-playbook playbooks/deploy-k3s.yml
```

Deploys K3s with High Availability (if 3+ master nodes).

**Configure kubectl after K3s deployment:**

```bash
# Set KUBECONFIG to point to the fetched kubeconfig file
export KUBECONFIG=~/arclink/ansible/kubeconfig

# Verify connection to cluster
kubectl get nodes

# Optional: Make it permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export KUBECONFIG=~/arclink/ansible/kubeconfig' >> ~/.bashrc
```

:::tip
The `kubeconfig` file is automatically fetched from the K3s master during the deployment.
:::

#### 6. Deploy Rancher (Optional but Recommended)

```bash
ansible-playbook playbooks/deploy-rancher.yml
```

Installs Rancher management UI for monitoring and managing your cluster.

:::info Deployment Order
Rancher is optional but recommended before Longhorn. Deploy in this order:
1. K3s cluster → 2. Rancher (optional) → 3. **Longhorn (required)** → 4. Registry → 5. Apps

Longhorn provides persistent storage required by OpenTAK Server and other applications.
:::

**What you get:**
- Web-based Kubernetes dashboard
- Real-time node monitoring and metrics
- Pod logs viewer and shell access
- Resource management (CPU, memory, storage)
- Easy namespace and workload management
- Certificate management
- Multi-cluster management capabilities

**Access Rancher:**
```text
https://rancher.research.core  # or your configured hostname
https://node0-ip:30443          # using NodePort
```

**First-time setup:**
1. Access Rancher URL in your browser
2. Set admin password (will be prompted on first visit)
3. Accept self-signed certificate warning (or configure proper SSL)
4. Rancher automatically detects and imports your local K3s cluster

**Duration:** ~5-10 minutes (includes cert-manager and Rancher installation)

:::tip Why Install Rancher?
Rancher provides invaluable visibility into your cluster, especially useful for:
- Debugging pod issues with real-time logs
- Monitoring node health and resource usage
- Quickly accessing pod shells without kubectl
- Visual management of deployments and services
- Centralized view of all cluster events
:::

#### 7. Deploy Longhorn Storage (Required)

```bash
ansible-playbook playbooks/deploy-longhorn.yml
```

:::warning Deploy Before Applications
**Must be deployed before registry and OpenTAK Server** as they require persistent volumes.
Longhorn provides distributed block storage across your cluster.
:::

Sets up distributed storage for persistent volumes.

#### 7. Deploy Registry

```bash
ansible-playbook playbooks/deploy-registry.yml
```

Starts local Docker registry for custom images.

#### 8. Deploy OpenTAKServer

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

Builds images with Socket.IO patches on the registry host, pushes to registry, and deploys to K3s.

**First run:** ~15-20 minutes (building images natively on registry host)  
**Subsequent runs:** ~3-5 minutes (Docker cache)

:::info Native Builds
Images are built directly on the registry host (node0) using its native architecture. This is faster and more reliable than cross-compiling from your control node.
:::

#### 10. Verify Deployment

```bash
# From your control node (using kubectl)
export KUBECONFIG=~/arclink/ansible/kubeconfig
kubectl get pods -n tak

# Or via Rancher UI
# Navigate to: Cluster → tak namespace → Workloads → Pods

# Expected output:
# NAME                             READY   STATUS    RESTARTS   AGE
# opentakserver-xxxxxxxxxx-xxxxx   2/2     Running   0          2m
# postgres-xxxxxxxxxx-xxxxx        1/1     Running   0          2m
# rabbitmq-xxxxxxxxxx-xxxxx        1/1     Running   0          2m
```

:::tip Using Rancher
Access Rancher at `https://rancher.research.core` (or your configured hostname) to:
- View real-time pod status and logs
- Monitor resource usage across all nodes
- Access pod shells directly from the web UI
- Check cluster events and troubleshoot issues visually
:::

### Verify Socket.IO Patches

```bash
ssh node0

POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  python3 -c "import opentakserver.extensions; print('✅ Patches verified!' if hasattr(opentakserver.extensions.socketio, 'cors_allowed_origins') else '❌ No patches')"
```

**Expected:** `✅ Patches verified!`

---

## Manual Scripts Approach

For more control or single-node deployments.

### Prerequisites

#### System Requirements
- ✅ K3s cluster already running
- ✅ Docker installed

#### Install kubectl (if not already installed)

```bash
# Download and install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Configure kubectl to use your K3s cluster
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# Or copy to standard location:
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verify connection
kubectl get nodes
```

### Step 1: Configure

```bash
cd ~/arclink
./scripts/configure.sh
```

Generates configuration and secrets.

### Step 2: Setup Docker Registry

For multi-node clusters, configure registry on all nodes:

```bash
# On each node
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["node0:5000"]
}
EOF

sudo systemctl restart docker
```

### Step 3: Build Images

```bash
cd ~/arclink/docker
./setup.sh
```

Builds OpenTAKServer and UI images.

**Duration:** ~30 minutes (first build)

### Step 4: Deploy to K3s

```bash
cd ~/arclink
./scripts/deploy.sh
```

Deploys PostgreSQL, RabbitMQ, and OpenTAKServer.

### Step 5: Verify

```bash
kubectl get pods -n opentakserver

# All pods should be Running
```

**Access:** `http://node0:8080` or configured port

---

## Quick Commands Reference

### Check Deployment Status

```bash
# All pods
kubectl get pods -n tak  # or -n opentakserver for manual approach

# Specific pod logs
kubectl logs -n tak <pod-name> -c opentakserver

# WebSocket logs
kubectl logs -n tak <pod-name> -c nginx | grep socket.io
```

### Update OpenTAKServer (Ansible)

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Duration:** ~3-5 minutes with Docker cache

### Reset Cluster (Ansible)

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/reset-cluster.yml
# Type 'yes' when prompted
```

Then redeploy from step 3.

### Restart Services

```bash
# Restart specific pod
kubectl delete pod -n tak <pod-name>

# Restart all OTS pods
kubectl rollout restart deployment/opentakserver -n tak
```

---

## Access the Application

### Web UI

```text
http://node0:31080  # Ansible deployment
http://node0:8080   # Manual deployment
```

Or use IP address:
```text
http://192.168.1.100:31080
```

### Default Login

- **Username:** `administrator`
- **Password:** `password`

:::danger Change Password
Change the default password immediately after first login!
:::

### Test WebSocket Connection

Open browser DevTools Console:
```javascript
const socket = io('http://node0:31080');
socket.on('connect', () => console.log('✅ WebSocket connected!'));
socket.on('disconnect', () => console.log('❌ Disconnected'));
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n tak

# Describe pod for details
kubectl describe pod -n tak <pod-name>

# Check events
kubectl get events -n tak --sort-by='.lastTimestamp'
```

### Image Pull Errors

```bash
# Verify registry running
curl -I http://node0:5000/v2/

# Check images in registry
curl http://node0:5000/v2/_catalog

# Restart pod to retry pull
kubectl delete pod -n tak <pod-name>
```

### WebSocket Not Working

```bash
# Check nginx logs
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n tak ${POD} -c nginx | grep socket.io

# Should see HTTP 200, not 400 errors

# Verify patches applied
kubectl exec -n tak ${POD} -c opentakserver -- \
  grep "cors_allowed_origins" /app/venv/lib/python*/site-packages/opentakserver/extensions.py
```

### Registry Issues (Ansible)

```bash
# Verify registry config on all nodes
ansible -i inventory/production.yml all -m shell \
  -a "cat /etc/rancher/k3s/registries.yaml"

# Test registry from all nodes
ansible -i inventory/production.yml all -m shell \
  -a "curl -I http://node0:5000/v2/"
```

---

## Next Steps

- **[Complete Deployment Guide](./complete-deployment.md)** - Detailed walkthrough
- **[Ansible Automation](./ansible/overview.md)** - Full Ansible documentation
- **[Configuration](./configuration.md)** - Customize your deployment
- **[Troubleshooting](./troubleshooting.md)** - Common issues and solutions

---

## What You've Deployed

✅ **K3s Cluster** - Kubernetes for edge/IoT  
✅ **Longhorn Storage** - Distributed persistent volumes (Ansible)  
✅ **Local Registry** - Private Docker registry  
✅ **OpenTAKServer** - With Socket.IO patches for WebSocket support  
✅ **PostgreSQL** - Database backend  
✅ **RabbitMQ** - Message queue  

Your OpenTAKServer is ready to use! 🎉
