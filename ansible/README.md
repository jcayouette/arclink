# Ansible Implementation for OpenTAKServer

This directory contains Ansible playbooks and roles for automating the deployment and management of OpenTAKServer on K3s clusters.

## Overview

Automate your entire K3s cluster deployment from system preparation through application deployment. Designed for **Raspberry Pi 5 High Availability clusters** but works with any cluster size (1, 3, or 7+ nodes).

**Key Features:**
- Automated SSH key distribution
- System preparation for K3s
- Local Docker registry setup
- High Availability K3s with embedded etcd
- OpenTAKServer with Socket.IO patches
- Support for Raspberry Pi 5 clusters

## 🖥️ Where to Run Commands

This guide uses **two different environments**. Pay attention to the prompt indicators:

### Control Node (WSL/Workstation)
```bash
# Indicated by: user@wsl:~$
user@wsl:~$ ansible-playbook playbooks/deploy-k3s.yml
```
- **Use for:** Ansible playbooks, inventory management, initial setup
- **Requires:** Ansible installed, SSH access to cluster nodes
- **Location:** Your workstation, WSL, or management machine

### Cluster Node (Primary Master)
```bash
# Indicated by: user@node0:~$
user@node0:~$ kubectl get pods -n tak
```
- **Use for:** kubectl commands, Docker builds, deployment verification
- **Requires:** SSH to node0 (primary master)
- **Location:** First master node in your cluster (node0)

### Either Location
Some operations work from both locations:
- **With Ansible installed on WSL:** Run everything via Ansible
- **Direct on node0:** Run kubectl/docker commands directly
- **Hybrid (recommended):** Use Ansible from WSL for infrastructure, SSH to node0 for application management

## Table of Contents
- [Fresh Installation](#fresh-installation)
- [Reset and Reinstall](#reset-and-reinstall)
- [OpenTAKServer Deployment](#opentakserver-deployment)
- [Troubleshooting](#troubleshooting)

## Fresh Installation

Complete guide for deploying from scratch on clean nodes.

### Prerequisites

**Control Node (WSL/Workstation):**
- Ansible 2.9+
- kubectl
- SSH access to all nodes

**Cluster Nodes:**
- Raspberry Pi 5 (or compatible ARM64/AMD64 hardware)
- Ubuntu Server 24.04 LTS
- Network connectivity
- Minimum 4GB RAM per node
- 32GB+ storage per node

### Step 1: Install Ansible (Control Node)

**📍 Location: WSL/Workstation**

```bash
user@wsl:~$ sudo apt update && sudo apt install -y ansible

# Install required collections
user@wsl:~$ ansible-galaxy collection install kubernetes.core community.docker community.general
```

> **Note:** Do NOT install Ansible on cluster nodes - run it from your workstation/WSL

### Step 2: Configure Inventory

**📍 Location: WSL/Workstation**

```bash
user@wsl:~$ cd ~/arclink/ansible

# Edit inventory with your node details
user@wsl:~$ vim inventory/production.yml
```

**Example inventory configuration:**
```yaml
all:
  children:
    k3s_cluster:
      children:
        k3s_master:
          hosts:
            node0:
              ansible_host: 10.0.0.160
        k3s_agents:
          hosts:
            node1:
              ansible_host: 10.0.0.161
            node2:
              ansible_host: 10.0.0.162
```

### Step 3: Bootstrap SSH Access

**📍 Location: WSL/Workstation**

Automatically distribute SSH keys to all nodes:

```bash
user@wsl:~$ cd ~/arclink/ansible
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/bootstrap.yml --ask-pass
```

This creates/copies your SSH key to all nodes and enables passwordless access.

### Step 4: Validate Prerequisites

**📍 Location: WSL/Workstation**

```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/validate-prerequisites.yml
```

Checks:
- Network connectivity
- SSH access
- User permissions
- System resources

### Step 5: System Preparation

**📍 Location: WSL/Workstation**

```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/setup-common.yml
```

Configures:
- System packages and updates
- Kernel modules (br_netfilter, overlay)
- Kernel parameters (IP forwarding, bridge settings)
- Timezone and system settings

### Step 6: Deploy Docker Registry

**📍 Location: WSL/Workstation**

```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/deploy-registry.yml
```

Creates a local Docker registry on primary master node for cluster-wide image distribution.

### Step 7: Deploy K3s Cluster

**📍 Location: WSL/Workstation**

```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/deploy-k3s.yml
```

Deploys:
- K3s masters with embedded etcd (HA)
- K3s agents joined to cluster
- kubectl access configured on primary master

**Verify cluster (from node0):**
```bash
user@wsl:~$ ssh node0
user@node0:~$ kubectl get nodes
# Should show all nodes Ready
```

### Step 8: Configure kubectl from Control Node (Optional)

**📍 Location: WSL/Workstation**

If you want to run kubectl from WSL instead of SSHing to node0:

```bash
user@wsl:~$ scp node0:~/.kube/config ~/arclink/ansible/kubeconfig

# Fix server address (from 127.0.0.1 to actual master IP)
user@wsl:~$ sed -i 's/127.0.0.1/10.0.0.160/g' ~/arclink/ansible/kubeconfig

# Set environment variable (add to ~/.bashrc for persistence)
user@wsl:~$ export KUBECONFIG=~/arclink/ansible/kubeconfig

# Test access
user@wsl:~$ kubectl get nodes
```

**Alternative:** Skip this step and just SSH to node0 for kubectl commands (simpler)

### Step 9: Deploy Longhorn Storage

**📍 Location: WSL/Workstation**

```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/deploy-longhorn.yml
```

**Verify (from node0):**
```bash
user@node0:~$ kubectl get pods -n longhorn-system
# Wait ~2-3 minutes for all pods to be Running
```

### Step 10: Deploy Rancher (Optional)

**📍 Location: WSL/Workstation**

```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/deploy-rancher.yml
```

Access Rancher:
- URL: `https://10.0.0.160:30443` (or your master IP)
- Initial password: `admin`

## OpenTAKServer Deployment

Deploy OpenTAKServer with Socket.IO patches for proper websocket functionality.

### Method 1: Automated Script (Recommended)

**📍 Location: Cluster Node (node0)**

Complete build and deployment in one command:
```bash
user@wsl:~$ ssh node0
user@node0:~$ cd ~/arclink
user@node0:~/arclink$ ./scripts/build-and-deploy.sh
```

This script:
1. Configures Docker for insecure registry
2. Builds images with Socket.IO patches (~3-5 min)
3. Pushes to local registry
4. Deploys to K3s
5. Verifies patches are applied

### Method 2: Ansible Playbook

**📍 Location: WSL/Workstation**

If you prefer running everything via Ansible:
```bash
user@wsl:~/arclink/ansible$ ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

> **Note:** This requires Ansible to be able to run Docker commands on node0

### Method 3: Manual Steps

**📍 Location: Cluster Node (node0)**

If you need to do it step-by-step:

```bash
user@wsl:~$ ssh node0
user@node0:~$ cd ~/arclink

# 1. Build images with Socket.IO patches
user@node0:~/arclink$ cd docker
REGISTRY=node0.research.core:5000 docker build --no-cache \
  --platform linux/arm64 \
  --build-arg OTS_VERSION=1.6.3 \
  -t node0.research.core:5000/opentakserver:1.6.3 \
  -t node0.research.core:5000/opentakserver:latest \
  -f opentakserver/Dockerfile opentakserver/

docker build --platform linux/arm64 \
  --build-arg UI_VERSION=master \
  -t node0.research.core:5000/opentakserver-ui:latest \
  -f ui/Dockerfile ui/

# 2. Push to registry
docker push node0.research.core:5000/opentakserver:1.6.3
docker push node0.research.core:5000/opentakserver:latest
docker push node0.research.core:5000/opentakserver-ui:latest

# 3. Deploy PostgreSQL and RabbitMQ
cd ~/arclink/manifests
kubectl create namespace tak --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f postgres.yaml
kubectl apply -f rabbitmq.yaml

# Wait for dependencies
kubectl wait --for=condition=ready pod -l app=postgres -n tak --timeout=120s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n tak --timeout=120s

# 4. Deploy OpenTAKServer with UI
kubectl apply -f nginx-config.yaml
kubectl apply -f ots-with-ui-custom-images.yaml

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=opentakserver -n tak --timeout=300s
```

### Verify OpenTAKServer Deployment

```bash
# Check all pods are running
kubectl get pods -n tak

# Should see:
# - postgres-0 (1/1 Running)
# - rabbitmq-0 (1/1 Running)  
# - opentakserver-xxx (2/2 Running) - both opentakserver and nginx containers

# Verify Socket.IO patches
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  cat /usr/local/lib/python3.12/site-packages/opentakserver/extensions.py | \
  grep "cors_allowed_origins"

# Should output: socketio = SocketIO(async_mode='gevent', cors_allowed_origins='*', logger=False, engineio_logger=False)

# Check websocket logs (should see HTTP 200, not 400)
kubectl logs -n tak ${POD} -c nginx --tail=20 | grep socket.io
```

### Access OpenTAKServer

**Web UI:**
- URL: `http://10.0.0.160:31080` (or your master IP)
- Default credentials: Set via admin password script

**Set Admin Password:**
```bash
# On master node
cd ~/arclink/scripts/helpers
./set-admin-password.sh YourSecurePassword
```

## Reset and Reinstall

### Complete Cluster Reset

**WARNING: This destroys all cluster data and configurations!**

```bash
# From control node
ansible-playbook playbooks/reset-cluster.yml

# Will prompt for confirmation: type 'yes'
```

This removes:
- K3s from all nodes
- Docker and configurations
- Rancher
- All persistent data
- System configurations

### After Reset: Fresh Installation

Once reset is complete, start fresh from [Step 3: Bootstrap SSH Access](#step-3-bootstrap-ssh-access).

SSH keys remain configured, so you can skip Step 3 unless you want to regenerate them.

### Partial Resets

**Reset just OpenTAKServer:**
```bash
kubectl delete namespace tak
# Then redeploy from OpenTAKServer Deployment section
```

**Reset just K3s (keep system configs):**
```bash
# On each master node
sudo /usr/local/bin/k3s-uninstall.sh

# On each agent node
sudo /usr/local/bin/k3s-agent-uninstall.sh

# Then redeploy from Step 7
```

## Socket.IO Patches Explained

OpenTAKServer requires specific Socket.IO patches for proper websocket functionality in Kubernetes environments.

### What Gets Patched

**Location:** `docker/opentakserver/Dockerfile`

**Patches Applied:**

1. **CORS Headers** (`extensions.py`)
   - Adds `cors_allowed_origins='*'` to Socket.IO initialization
   - Allows nginx reverse proxy to forward websocket connections
   - Without this: HTTP 400 errors on Socket.IO POST requests

2. **RabbitMQ Message Queue Removal** (`app.py`)
   - Removes `message_queue="amqp://..."` from socketio.init_app()
   - RabbitMQ queue doesn't persist across pod restarts in K8s
   - Without this: Sessions lost on pod restart

3. **Ping Timeout Increase** (`app.py`)
   - Changes `ping_timeout=1` to `ping_timeout=60`
   - Prevents premature connection timeouts
   - Without this: Frequent reconnection attempts

### How Patches Are Applied

The Dockerfile uses a Python heredoc to automatically detect the Python version and patch the correct files:

```dockerfile
RUN python3 <<'PATCHEOF'
import re, glob

# Auto-detect Python site-packages path
site_packages = glob.glob("/usr/local/lib/python*/site-packages")[0]

# Patch extensions.py for CORS
extensions_file = f"{site_packages}/opentakserver/extensions.py"
with open(extensions_file, "r") as f:
    content = f.read()
content = content.replace(
    "socketio = SocketIO(async_mode='gevent')",
    "socketio = SocketIO(async_mode='gevent', cors_allowed_origins='*', logger=False, engineio_logger=False)"
)
with open(extensions_file, "w") as f:
    f.write(content)

# Patch app.py for message_queue and timeout
# ... (full script in Dockerfile)
PATCHEOF
```

### Verifying Patches

```bash
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')

# Check CORS patch
kubectl exec -n tak ${POD} -c opentakserver -- \
  grep "cors_allowed_origins" /usr/local/lib/python3.12/site-packages/opentakserver/extensions.py

# Should output: socketio = SocketIO(async_mode='gevent', cors_allowed_origins='*', ...)

# Check websocket functionality (should see HTTP 200)
kubectl logs -n tak ${POD} -c nginx --tail=20 | grep socket.io
```

## Troubleshooting & Monitoring

### Ansible Verbosity Levels
```bash
# Basic verbosity (recommended for most cases)
ansible-playbook playbooks/deploy-k3s.yml -v

# Detailed output (shows command results)
ansible-playbook playbooks/deploy-k3s.yml -vv

# Very detailed (includes connection debugging)
ansible-playbook playbooks/deploy-k3s.yml -vvv

# Debug level (everything - use for troubleshooting)
ansible-playbook playbooks/deploy-k3s.yml -vvvv
```

### Monitor Logs During Operations
```bash
# SSH to node and monitor Docker operations
ssh acmeastro@10.0.0.160

# Watch Docker containers
sudo docker ps -a

# Follow container logs
sudo docker logs -f <container_name>

# Monitor system logs
journalctl -fu docker
journalctl -fu k3s
```

### Check Deployment Status
```bash
# View all pods across all namespaces
kubectl get pods -A

# Watch pod status in real-time
kubectl get pods -n tak -w

# Check pod logs
kubectl logs -f <pod-name> -n tak

# Describe pod for troubleshooting
kubectl describe pod <pod-name> -n tak

# Check events
kubectl get events -n tak --sort-by='.lastTimestamp'
```

### Common Issues

#### PostgreSQL CrashLoopBackOff

**Symptom:** `postgres-0` pod stuck in CrashLoopBackOff

**Cause:** Longhorn volume contains `lost+found` directory, PostgreSQL requires empty data directory

**Fix:**
```bash
kubectl delete pod postgres-0 -n tak
# Pod will recreate with PGDATA=/var/lib/postgresql/data/pgdata (subdirectory)
```

#### ImagePullBackOff Errors

**Symptom:** Pods can't pull images from registry

**Cause:** K3s not configured for insecure registry

**Fix:**
```bash
# On each node
sudo tee /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "node0.research.core:5000":
    endpoint:
      - "http://node0.research.core:5000"
  "10.0.0.160:5000":
    endpoint:
      - "http://10.0.0.160:5000"
EOF

# Restart K3s
# On masters:
sudo systemctl restart k3s

# On agents:
sudo systemctl restart k3s-agent
```

#### WebSocket HTTP 400 Errors

**Symptom:** Browser console shows Socket.IO 400 errors, map not updating in real-time

**Cause:** Image deployed without Socket.IO patches

**Fix:**
```bash
# Rebuild images with patches
cd ~/arclink
./scripts/build-and-deploy.sh

# Or manually rebuild
cd ~/arclink/docker
docker build --no-cache --platform linux/arm64 \
  -t node0.research.core:5000/opentakserver:latest \
  -f opentakserver/Dockerfile opentakserver/

docker push node0.research.core:5000/opentakserver:latest

# Force pod to pull new image
kubectl patch deployment opentakserver -n tak \
  --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Always"}]'

kubectl delete pod -n tak -l app=opentakserver
```

#### OpenTAKServer Container Using Wrong Image

**Symptom:** Patches verified in image but not in running container

**Cause:** Registry cached old image with same tag

**Fix:**
```bash
# Always set imagePullPolicy: Always for development
kubectl patch deployment opentakserver -n tak \
  --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Always"}]'

# Delete pod to force fresh pull
kubectl delete pod -n tak -l app=opentakserver
```

#### Longhorn Volumes Not Attaching

**Symptom:** Pods stuck in ContainerCreating, events show volume attach errors

**Cause:** Longhorn components not ready or missing iSCSI tools

**Fix:**
```bash
# Check Longhorn status
kubectl get pods -n longhorn-system

# All pods should be Running

# If issues, check iSCSI on nodes
ssh node0
sudo systemctl status iscsid
sudo systemctl enable --now iscsid

# Redeploy Longhorn if needed
kubectl delete namespace longhorn-system
ansible-playbook playbooks/deploy-longhorn.yml
```

#### Kubectl Access Issues from Master Node

**Symptom:** `kubectl` commands fail on master node

**Cause:** Kubeconfig not configured

**Fix:**
```bash
# On master node
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# Fix server address
sed -i "s/127.0.0.1/$(hostname -I | awk '{print $1}')/g" ~/.kube/config

# Test
kubectl get nodes
```

## Directory Structure

```
ansible/
├── inventory/
│   ├── production.yml          # 7-node reference cluster (3 masters + 4 agents)
│   └── group_vars/
│       ├── all.yml             # Global variables (domain, registry, versions)
│       ├── k3s_master.yml      # Master config (HA, etcd, API settings)
│       └── k3s_agents.yml      # Agent config (labels, taints)
├── playbooks/
│   ├── bootstrap.yml           # SSH key distribution
│   ├── validate-prerequisites.yml  # Cluster readiness checks
│   ├── setup-common.yml        # System preparation
│   ├── deploy-registry.yml     # Docker registry setup
│   └── deploy-k3s.yml          # K3s cluster deployment
├── roles/
│   ├── common/                 # System prep (packages, kernel, /etc/hosts)
│   ├── docker-registry/        # Registry container + K3s config
│   ├── k3s-master/             # K3s control plane with HA support
│   └── k3s-agent/              # K3s worker nodes
├── ansible.cfg                 # Ansible configuration
├── SETUP.md                    # Detailed setup guide
└── README.md                   # This file
```

## Implementation Status

### Phase 1: Production Inventory ✅ COMPLETE
- ✅ 7-node inventory (3 masters + 4 agents)
- ✅ Group variables organized
- ✅ Bootstrap playbook for SSH automation
- ✅ Prerequisite validation playbook

### Phase 2: Common Role ✅ COMPLETE
- ✅ Package installation (curl, wget, socat, conntrack)
- ✅ Kernel modules (br_netfilter, overlay)
- ✅ Sysctl configuration (IP forwarding, bridge netfilter)
- ✅ /etc/hosts with all cluster nodes
- ✅ Swap disabled

### Phase 3: K3s Deployment ✅ COMPLETE
- ✅ Docker registry role (registry:2 container)
- ✅ K3s master role (HA with --cluster-init)
- ✅ K3s agent role (cluster join)
- ✅ Registry deployment playbook
- ✅ K3s deployment playbook
- ✅ Tested and operational

### Phase 4: Infrastructure Services ✅ COMPLETE
- ✅ Longhorn distributed storage
- ✅ Rancher management UI (NodePort 30443)
- ✅ Cert-manager for certificate management

### Phase 5: Application Deployment ✅ COMPLETE
- ✅ OpenTAKServer image build with Socket.IO patches
- ✅ OpenTAKServer UI image build
- ✅ PostgreSQL with Longhorn persistence (PGDATA subdirectory fix)
- ✅ RabbitMQ deployment
- ✅ Application deployment playbook
- ✅ Automated deployment script (build-and-deploy.sh)
- ✅ WebSocket functionality verified
- ✅ Testing and validation complete

## Supported Cluster Topologies

### Single Node (Development)
```yaml
k3s_master:
  hosts:
    node0.research.core
```
- No HA, simplest setup for testing

### Three Nodes (HA - Recommended)
```yaml
k3s_master:
  hosts:
    node0.research.core  # Primary master with cluster-init
    node1.research.core  # Additional master
    node2.research.core  # Additional master
```
- **True High Availability** with embedded etcd
- Survives 1 node failure (quorum: 2/3)
- Ideal for production Raspberry Pi clusters

### Large Cluster (7+ nodes)
```yaml
k3s_master:
  hosts:
    node0.research.core  # HA control plane
    node1.research.core
    node2.research.core
k3s_agents:
  hosts:
    node3.research.core  # Worker nodes
    node4.research.core
    node5.research.core
    node6.research.core
```
- HA control plane + dedicated workers
- Better workload distribution
- Our reference implementation

## Playbook Execution Order

```bash
# 1. Bootstrap SSH access (run once)
ansible-playbook playbooks/bootstrap.yml --ask-pass

# 2. Validate prerequisites
ansible-playbook playbooks/validate-prerequisites.yml

# 3. System preparation (all nodes)
ansible-playbook playbooks/setup-common.yml

# 4. Deploy Docker registry (master)
ansible-playbook playbooks/deploy-registry.yml

# 5. Deploy K3s cluster (masters + agents)
ansible-playbook playbooks/deploy-k3s.yml

# 6. Verify deployment
export KUBECONFIG=~/arclink/ansible/kubeconfig
kubectl get nodes -o wide
```

## Key Features

### Automated SSH Setup
- `bootstrap.yml` handles SSH key generation and distribution
- One password prompt, then passwordless access
- No manual `ssh-copy-id` required

### High Availability Support
- Automatic HA detection (3+ masters)
- Embedded etcd cluster
- `--cluster-init` on primary master
- Additional masters join via `--server` flag

### Local Registry
- Docker registry:2 on primary master (port 5000)
- Automatic registry configuration on all nodes
- `/etc/rancher/k3s/registries.yaml` for insecure registry

### System Optimization
- Kernel modules: `br_netfilter`, `overlay`
- Sysctl: IP forwarding, bridge netfilter
- Swap disabled (K3s requirement)
- /etc/hosts with all cluster nodes

## Architecture

### Control Node
- Runs on workstation/WSL (not cluster nodes)
- Ansible 2.9+ required
- SSH access to all cluster nodes
- No circular dependencies

### Cluster Nodes
- Ubuntu 24.04 LTS (Raspberry Pi)
- Python 3 installed
- Passwordless sudo configured
- Static IPs on 10.0.0.0/24 network

### K3s Configuration
- Version: v1.33.5+k3s1 (upgrade to v1.33.6+k3s1 available)
- Disabled: Traefik, ServiceLB (use alternatives)
- Cluster CIDR: 10.42.0.0/16
- Service CIDR: 10.43.0.0/16
- Embedded etcd for HA (3+ masters)

## Variables Reference

### Global (group_vars/all.yml)
- `domain`: Cluster domain (research.core)
- `registry_url`: Local registry (node0:5000)
- `k3s_version`: K3s release version
- `cluster_cidr`: Pod network range
- `service_cidr`: Service network range

### Master-Specific (group_vars/k3s_master.yml)
- `k3s_ha_mode`: Auto-detected (3+ masters)
- `k3s_server_flags`: Additional K3s flags
- `k3s_cluster_init_timeout`: Cluster init wait time

### Agent-Specific (group_vars/k3s_agents.yml)
- `k3s_agent_flags`: Additional K3s flags
- Node labels and taints (optional)

## Troubleshooting

### SSH Issues
```bash
# Test connectivity
ansible all -m ping

# Regenerate keys
rm ~/.ssh/id_ed25519*
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

### Sudo Issues
```bash
# Test sudo access
ansible all -m command -a "sudo whoami"

# Fix manually on each node
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
```

### K3s Installation Issues
```bash
# Check K3s service status
ansible k3s_master -m command -a "systemctl status k3s"

# View K3s logs
ansible k3s_master -m command -a "journalctl -u k3s -n 50"

# Uninstall and retry
ansible k3s_cluster -m command -a "/usr/local/bin/k3s-uninstall.sh"
```

### Registry Issues
```bash
# Test registry accessibility
ansible all -m uri -a "url=http://node0.research.core:5000/v2/ status_code=200"

# Check registries.yaml
ansible all -m command -a "cat /etc/rancher/k3s/registries.yaml"
```

## Next Steps

1. **Complete Phase 3 Testing**
   - Deploy registry and K3s
   - Verify all nodes Ready
   - Test registry push/pull

2. **Install Storage (Phase 4)**
   - Deploy Longhorn for distributed storage
   - Configure StorageClass
   - Test PVC provisioning

3. **Deploy Applications**
   - Build OpenTAKServer images
   - Deploy PostgreSQL + RabbitMQ
   - Configure certificates
   - Deploy OpenTAKServer pods

## Documentation

- **SETUP.md**: Detailed setup guide with prerequisites
- **docs/guides/ansible/progress-checklist.md**: Implementation tracking
- **docs/guides/ansible/overview.md**: Ansible benefits and architecture
- **docs/guides/ansible/high-availability.md**: Application-level HA guide

## Quick Reference

### Complete Fresh Installation (TL;DR)

```bash
# 1. Install Ansible on control node
sudo apt update && sudo apt install -y ansible
ansible-galaxy collection install kubernetes.core community.docker community.general

# 2. Configure inventory
cd ~/arclink/ansible
vim inventory/production.yml

# 3. Bootstrap SSH
ansible-playbook playbooks/bootstrap.yml --ask-pass

# 4. Validate
ansible-playbook playbooks/validate-prerequisites.yml

# 5. Deploy infrastructure
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-k3s.yml

# 6. Configure kubectl
scp node0:~/.kube/config kubeconfig
sed -i 's/127.0.0.1/10.0.0.160/g' kubeconfig
export KUBECONFIG=~/arclink/ansible/kubeconfig

# 7. Deploy storage and management
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-rancher.yml

# 8. Deploy OpenTAKServer (SSH to primary master)
ssh node0
cd ~/arclink
./scripts/build-and-deploy.sh
```

### Common Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl get pvc -A

# Check OpenTAKServer
kubectl get pods -n tak
kubectl logs -n tak -l app=opentakserver -c opentakserver --tail=50
kubectl logs -n tak -l app=opentakserver -c nginx --tail=50

# Restart OpenTAKServer
kubectl delete pod -n tak -l app=opentakserver

# Reset cluster
ansible-playbook playbooks/reset-cluster.yml

# Rebuild OpenTAKServer with patches
ssh node0
cd ~/arclink
./scripts/build-and-deploy.sh
```

### Access Points

- **Rancher UI:** `https://10.0.0.160:30443` (NodePort)
- **OpenTAKServer Web:** `http://10.0.0.160:31080` (NodePort)
- **OpenTAKServer TCP CoT:** `10.0.0.160:31088`
- **OpenTAKServer SSL CoT:** `10.0.0.160:31089`
- **Docker Registry:** `http://10.0.0.160:5000`

### Important Files

- **Inventory:** `inventory/production.yml`
- **Kubeconfig:** `~/arclink/ansible/kubeconfig`
- **Docker Build:** `docker/opentakserver/Dockerfile` (Socket.IO patches)
- **Deployment Script:** `scripts/build-and-deploy.sh`
- **Ansible Playbook:** `playbooks/deploy-opentakserver-with-patches.yml`
- **Manifests:** `manifests/ots-with-ui-custom-images.yaml`

## Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [K3s Documentation](https://docs.k3s.io/)
- [kubernetes.core Collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [K3s Ansible Examples](https://github.com/k3s-io/k3s-ansible)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [OpenTAKServer GitHub](https://github.com/brian7704/OpenTAKServer)
- [Rancher Documentation](https://ranchermanager.docs.rancher.com/)
