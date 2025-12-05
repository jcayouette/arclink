---
sidebar_position: 2
---

# Complete Getting Started Guide

Comprehensive walkthrough from bare metal Raspberry Pi nodes to fully deployed OpenTAKServer with High Availability.

:::tip Tested Configuration
7-node Raspberry Pi 5 cluster (3 masters + 4 agents) with embedded etcd, tested December 4, 2025
:::

## What You'll Build

- **K3s Cluster:** HA with 3 master nodes + 4 agent nodes
- **Distributed Storage:** Longhorn across all nodes
- **Local Registry:** Private Docker registry for custom images
- **OpenTAKServer:** With Socket.IO patches for WebSocket support
- **Backend Services:** PostgreSQL + RabbitMQ

**Total Deployment Time:** ~45 minutes (first run), ~15 minutes (subsequent)

## Two Environments

You'll work in two different places:

### 1. Control Node (WSL/Workstation)
```bash
user@wsl:~/arclink/ansible$
```
**Used for:** Running Ansible playbooks, managing infrastructure

### 2. Cluster Node (Primary Master - node0)
```bash
user@node0:~/arclink$
```
**Used for:** kubectl commands, verification, troubleshooting

## Prerequisites

### Hardware Requirements

**Tested:** Raspberry Pi 5 8GB
**Minimum per node:**
- 4GB RAM
- 32GB storage
- Network connectivity

**Cluster Sizes:**
- Single node: 1 master (no HA)
- HA cluster: 3+ masters (must be odd: 3, 5, 7) + any number of agents

### Software Requirements

**Cluster Nodes:**
- ✅ Ubuntu Server 24.04 LTS installed
- ✅ Static IP addresses configured
- ✅ SSH enabled
- ✅ All nodes can reach each other

**Control Node (where you run Ansible):**
- ✅ Ansible 2.9+ installed
- ✅ SSH client
- ✅ Network access to all cluster nodes

## Installation Steps

### Step 0: Install Ansible (Control Node)

**📍 Location: WSL/Workstation**

```bash
# Install Ansible
sudo apt update && sudo apt install -y ansible

# Install required collections
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.general

# Verify installation
ansible --version
```

**Expected output:**
```
ansible [core 2.12.x]
...
```

---

### Step 1: Configure Inventory

**📍 Location: WSL/Workstation**

```bash
cd ~/arclink/ansible
nano inventory/production.yml
```

**Example configuration:**

```yaml
all:
  vars:
    # SSH user for all nodes
    ansible_user: acmeastro
    
    # Enable sudo
    ansible_become: yes
    
    # Registry configuration
    registry_address: "node0.research.core:5000"
    
    # OpenTAKServer version
    ots_version: "1.6.3"
    
    # Kubernetes namespace
    namespace: "tak"
    
  children:
    k3s_cluster:
      children:
        # Master nodes (HA requires odd number: 3, 5, 7)
        k3s_master:
          hosts:
            node0.research.core:
              ansible_host: 10.0.0.160
              k3s_master_primary: true  # First master
            node1.research.core:
              ansible_host: 10.0.0.161
            node2.research.core:
              ansible_host: 10.0.0.162
        
        # Agent nodes (any number)
        k3s_agents:
          hosts:
            node3.research.core:
              ansible_host: 10.0.0.163
            node4.research.core:
              ansible_host: 10.0.0.164
            node5.research.core:
              ansible_host: 10.0.0.165
            node6.research.core:
              ansible_host: 10.0.0.166
```

**For single-node deployment:**
```yaml
all:
  vars:
    ansible_user: yourusername
    ansible_become: yes
    registry_address: "node0:5000"
    
  children:
    k3s_cluster:
      children:
        k3s_master:
          hosts:
            node0:
              ansible_host: 192.168.1.100
```

---

### Step 2: Bootstrap SSH Access

**📍 Location: WSL/Workstation**

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

**Prompt:** Enter your SSH password when asked

**What it does:**
- Creates SSH key pair if it doesn't exist
- Copies public key to all nodes
- Enables passwordless SSH for future commands
- No need to enter passwords again!

**Duration:** ~1 minute

**Verify:**
```bash
ansible -i inventory/production.yml all -m ping
```

**Expected output:**
```
node0.research.core | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
node1.research.core | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
...
```

---

### Step 3: Validate Prerequisites

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/validate-prerequisites.yml
```

**What it checks:**
- Network connectivity to all nodes
- SSH access working
- User has sudo privileges
- Minimum system resources
- Python installed
- Required ports available

**Duration:** ~30 seconds

**If validation fails:**
- Check inventory hostnames/IPs
- Verify SSH keys distributed
- Ensure sudo access configured
- Check firewall rules

---

### Step 4: System Preparation

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/setup-common.yml
```

**What it does:**
- Installs required packages:
  - curl, apt-transport-https, ca-certificates
  - software-properties-common
  - docker.io
- Loads kernel modules:
  - br_netfilter (bridge networking)
  - overlay (container filesystems)
  - ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh (load balancing)
- Configures sysctl parameters:
  - IP forwarding enabled
  - Bridge networking configured
  - Connection tracking settings
- Updates system packages
- Sets timezone
- Configures /etc/hosts for cluster nodes

**Duration:** ~3-5 minutes

**Verify:**
```bash
# Check kernel modules loaded
ansible -i inventory/production.yml all -m shell -a "lsmod | grep br_netfilter"

# Check sysctl settings
ansible -i inventory/production.yml all -m shell -a "sysctl net.ipv4.ip_forward"
```

---

### Step 5: Deploy K3s Cluster

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/deploy-k3s.yml
```

**What it does:**

1. **First Master (node0):**
   - Installs K3s with embedded etcd
   - Configures as cluster-init
   - Retrieves join token
   - Saves kubeconfig

2. **Additional Masters (node1, node2):**
   - Joins HA cluster with embedded etcd
   - Uses join token from node0

3. **Agent Nodes (node3-6):**
   - Joins cluster as workers
   - Connects to all master nodes

4. **Post-deployment:**
   - Configures kubectl on all masters
   - Validates all nodes joined
   - Checks cluster health

**Duration:** ~5-10 minutes

**Verify:**
```bash
# SSH to node0
ssh node0

# Check cluster nodes
kubectl get nodes

# Expected output:
# NAME                    STATUS   ROLES                       AGE     VERSION
# node0.research.core     Ready    control-plane,etcd,master   5m      v1.28.x+k3s1
# node1.research.core     Ready    control-plane,etcd,master   4m      v1.28.x+k3s1
# node2.research.core     Ready    control-plane,etcd,master   4m      v1.28.x+k3s1
# node3.research.core     Ready    <none>                      3m      v1.28.x+k3s1
# node4.research.core     Ready    <none>                      3m      v1.28.x+k3s1
# node5.research.core     Ready    <none>                      3m      v1.28.x+k3s1
# node6.research.core     Ready    <none>                      3m      v1.28.x+k3s1

# Check all pods running
kubectl get pods -A

# All system pods should be Running
```

---

### Step 6: Deploy Longhorn Storage

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/deploy-longhorn.yml
```

**What it does:**
- Applies Longhorn deployment manifest
- Creates StorageClass `longhorn`
- Configures 3 replicas for data redundancy
- Waits for all Longhorn pods to be ready
- Makes Longhorn the default storage class

**Duration:** ~2-3 minutes

**Verify:**
```bash
ssh node0

# Check Longhorn pods
kubectl get pods -n longhorn-system

# Should see multiple pods all Running

# Check storage class
kubectl get storageclass

# Expected output:
# NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ...
# longhorn (default)   driver.longhorn.io   Delete          Immediate           ...
```

---

### Step 7: Deploy Docker Registry

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/deploy-registry.yml
```

**What it does:**
- Starts Docker registry on node0:5000
- Persists images to `/var/lib/registry`
- Configures K3s to trust insecure registry
- Configures Docker daemon on all nodes
- Restarts services with new config

**Duration:** ~2 minutes

**Verify:**
```bash
ssh node0

# Check registry running
docker ps | grep registry

# Test registry API
curl -I http://node0.research.core:5000/v2/

# Expected: HTTP/1.1 200 OK
```

---

### Step 8: Deploy OpenTAKServer

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Prompt:** Enter sudo password when asked (needed for Docker daemon configuration)

**What it does:**

1. **Configure Docker:**
   - Adds insecure registry to `/etc/docker/daemon.json`
   - Restarts Docker daemon

2. **Clone Repository:**
   - Clones arclink to node0
   - Ensures latest code

3. **Build OpenTAKServer Image:**
   - Applies Socket.IO patches:
     - Enables CORS: `cors_allowed_origins='*'`
     - Removes RabbitMQ message_queue
     - Increases ping timeout to 60 seconds
   - Auto-detects Python version (supports 3.11, 3.12, 3.13)
   - Builds with tag `node0.research.core:5000/opentakserver:1.6.3`
   - Uses Docker layer cache (subsequent builds ~3-5 min)

4. **Build UI Image:**
   - nginx configuration for WebSocket proxy
   - Builds with tag `node0.research.core:5000/ui:latest`

5. **Push to Registry:**
   - Pushes both images to local registry
   - Makes available to all cluster nodes

6. **Deploy to Kubernetes:**
   - Deletes existing deployment (if any)
   - Applies manifest with custom images
   - Creates namespace `tak`
   - Deploys PostgreSQL, RabbitMQ, OpenTAKServer
   - Waits for pods to be ready

7. **Verify Patches:**
   - Checks running container for Socket.IO patches
   - Confirms CORS enabled

**Duration:** 
- First run: ~30 minutes (building images)
- Subsequent runs: ~3-5 minutes (Docker cache)

**Verify:**
```bash
ssh node0

# Check pods
kubectl get pods -n tak

# Expected output:
# NAME                             READY   STATUS    RESTARTS   AGE
# opentakserver-xxxxxxxxxx-xxxxx   2/2     Running   0          2m
# postgres-xxxxxxxxxx-xxxxx        1/1     Running   0          2m
# rabbitmq-xxxxxxxxxx-xxxxx        1/1     Running   0          2m

# Verify Socket.IO patches
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  python3 -c "import opentakserver.extensions; print('✅ Patches verified!' if hasattr(opentakserver.extensions.socketio, 'cors_allowed_origins') else '❌ No patches')"

# Check WebSocket logs (should see HTTP 200, not 400)
kubectl logs -n tak ${POD} -c nginx --tail=50 | grep socket.io
```

---

### Step 9: Validate Deployment

**📍 Location: WSL/Workstation**

```bash
ansible-playbook playbooks/validate-k3s-cluster.yml
```

**What it checks:**
- All nodes in Ready state
- System pods running
- Longhorn healthy
- Registry accessible
- API server responsive
- Application pods running

**Duration:** ~30 seconds

---

## Access Your Deployment

### Web UI

```
http://node0.research.core:31080
```

Or use IP address:
```
http://10.0.0.160:31080
```

### Default Credentials

- **Username:** `administrator`
- **Password:** `password`

:::danger Change Password
Change the default password immediately after first login!
:::

### Test WebSocket Connection

In browser DevTools Console:
```javascript
const socket = io('http://node0.research.core:31080');
socket.on('connect', () => console.log('✅ WebSocket connected!'));
socket.on('disconnect', () => console.log('❌ WebSocket disconnected'));
```

You should see "✅ WebSocket connected!"

---

## Common Workflows

### Update OpenTAKServer Only

```bash
# Rebuild and redeploy
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Duration:** ~3-5 minutes (Docker cache)

---

### Complete Cluster Reset

```bash
# Teardown everything
ansible-playbook playbooks/reset-cluster.yml
# Type 'yes' when prompted

# Redeploy from scratch (skip bootstrap if already done)
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Duration:** ~15 minutes (with Docker cache)

---

### Add Agent Node

1. **Update inventory:**
   ```yaml
   k3s_agents:
     hosts:
       # ... existing nodes ...
       node7.research.core:
         ansible_host: 10.0.0.167
   ```

2. **Bootstrap new node:**
   ```bash
   ansible-playbook playbooks/bootstrap.yml --limit=node7 --ask-pass
   ansible-playbook playbooks/setup-common.yml --limit=node7
   ```

3. **Join to cluster:**
   ```bash
   ansible-playbook playbooks/deploy-k3s.yml --limit=node7
   ```

4. **Verify:**
   ```bash
   ssh node0
   kubectl get nodes
   ```

---

### Remove Node

```bash
# SSH to node0
ssh node0

# Drain node
kubectl drain node7.research.core --delete-emptydir-data --force --ignore-daemonsets

# Delete from cluster
kubectl delete node node7.research.core

# Remove from inventory
nano inventory/production.yml  # Remove node7 entry
```

---

## Troubleshooting

### SSH Connection Issues

```bash
# Test connectivity
ansible -i inventory/production.yml all -m ping

# Check SSH with verbose output
ssh -v node0

# Verify inventory
ansible-inventory -i inventory/production.yml --list
```

---

### K3s Installation Failed

```bash
# Check logs on affected node
ssh node0
journalctl -u k3s -n 100 -f

# Verify ports not in use
ss -tulpn | grep -E ':(6443|10250|2379|2380)'

# Check kernel modules
lsmod | grep -E '(br_netfilter|overlay|ip_vs)'
```

---

### Pods Not Starting

```bash
ssh node0

# Describe pod for details
kubectl describe pod -n tak <pod-name>

# Check events
kubectl get events -n tak --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n tak <pod-name> -c <container-name>

# Common issues:
# - Image pull errors: Check registry connectivity
# - Insufficient resources: Check node resources
# - Storage issues: Check Longhorn status
```

---

### Registry Pull Failures

```bash
# Verify registry running
ssh node0
docker ps | grep registry

# Test from all nodes
ansible -i inventory/production.yml all -m shell \
  -a "curl -I http://node0.research.core:5000/v2/"

# Check K3s registry config
cat /etc/rancher/k3s/registries.yaml

# Check Docker daemon config
cat /etc/docker/daemon.json

# Restart services if needed
sudo systemctl restart docker
sudo systemctl restart k3s
```

---

### Socket.IO Not Working

```bash
# Verify patches applied
ssh node0
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  grep "cors_allowed_origins" /app/venv/lib/python*/site-packages/opentakserver/extensions.py

# Should see: cors_allowed_origins='*',

# Check nginx proxy config
kubectl exec -n tak ${POD} -c nginx -- cat /etc/nginx/nginx.conf | grep -A 10 socket.io

# Check WebSocket logs
kubectl logs -n tak ${POD} -c nginx --tail=100 | grep socket.io
```

---

### Docker Build Fails

```bash
# Clear cache and rebuild
ssh node0
docker system prune -af  # Warning: removes all unused data

# Rebuild from control node
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

---

## Next Steps

- **[Overview](./overview.md)** - Complete documentation of all features
- **[Quick Start](./quick-start.md)** - Fast deployment for repeat installs
- **[High Availability](./high-availability.md)** - HA configuration details
- **[Progress Checklist](./progress-checklist.md)** - Implementation status

## What You've Accomplished

✅ **High Availability K3s Cluster** - 7 nodes with embedded etcd  
✅ **Distributed Storage** - Longhorn with 3 replicas  
✅ **Local Registry** - Private Docker registry  
✅ **OpenTAKServer** - With working WebSocket support  
✅ **Complete Automation** - Reproducible deployments  

Your infrastructure is production-ready! 🎉
