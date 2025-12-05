---
sidebar_position: 2
---

# Complete Deployment Guide

Comprehensive walkthrough from bare metal to fully deployed OpenTAKServer with High Availability.

:::tip Production Ready
This guide walks you through a production-grade deployment tested on a 7-node Raspberry Pi 5 cluster.
:::

## Overview

This guide covers:
- Hardware requirements and cluster sizing
- Complete infrastructure deployment with Ansible
- OpenTAKServer deployment with Socket.IO patches
- Verification and troubleshooting
- Common workflows

**Time to Deploy:** ~45 minutes (first time), ~15 minutes (subsequent)

---

## Hardware Requirements

### Tested Configuration

**Our Test Cluster:**
- 7x Raspberry Pi 5 (8GB)
- 3 master nodes (HA with embedded etcd)
- 4 agent nodes (workloads)
- Ubuntu Server 24.04 LTS

### Minimum Requirements per Node

- **CPU:** 4 cores (ARM64 or AMD64)
- **RAM:** 4GB minimum, 8GB recommended
- **Storage:** 32GB minimum, 64GB+ recommended
- **Network:** Gigabit Ethernet recommended

### Cluster Sizing Options

#### Single Node (Development)
- 1 master node
- No high availability
- Good for testing and development

#### Three Nodes (HA Minimum)
- 3 master nodes with embedded etcd
- True high availability
- Survives 1 node failure
- **Recommended for production**

#### Seven+ Nodes (Large Cluster)
- 3 master nodes (HA)
- 4+ agent nodes (workloads)
- Better workload distribution
- Higher capacity

---

## Prerequisites

### Control Node (Your Workstation/WSL)

Where you run Ansible commands:

- ✅ Ansible 2.9+ installed
- ✅ Python 3.8+
- ✅ SSH client
- ✅ Network access to all cluster nodes

**Install Ansible:**
```bash
# Ubuntu/Debian/WSL
sudo apt update && sudo apt install -y ansible

# macOS
brew install ansible

# Install required collections
ansible-galaxy collection install kubernetes.core community.docker community.general
```

### Cluster Nodes

All Raspberry Pi or servers:

- ✅ Ubuntu Server 24.04 LTS installed
- ✅ Static IP addresses configured
- ✅ SSH enabled
- ✅ Python 3 installed (included in Ubuntu)
- ✅ All nodes can reach each other on network

---

## Deployment Steps

### Step 0: Configure Inventory

**📍 Location: Control Node (WSL/Workstation)**

```bash
cd ~/arclink/ansible
nano inventory/production.yml
```

**Example for 7-node cluster:**

```yaml
all:
  vars:
    # SSH user for all nodes
    ansible_user: yourusername
    
    # Enable sudo
    ansible_become: yes
    
    # Registry configuration
    registry_address: "node0.yourdomain.com:5000"
    
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
            node0.yourdomain.com:
              ansible_host: 192.168.1.100
            node1.yourdomain.com:
              ansible_host: 192.168.1.101
            node2.yourdomain.com:
              ansible_host: 192.168.1.102
        
        # Agent nodes (any number)
        k3s_agents:
          hosts:
            node3.yourdomain.com:
              ansible_host: 192.168.1.103
            node4.yourdomain.com:
              ansible_host: 192.168.1.104
            node5.yourdomain.com:
              ansible_host: 192.168.1.105
            node6.yourdomain.com:
              ansible_host: 192.168.1.106
```

**For single-node cluster:**
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

### Step 1: Bootstrap SSH Access

**📍 Location: Control Node**

Setup passwordless SSH authentication:

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

**Prompt:** Enter your SSH password when asked

**What it does:**
- Creates SSH key pair if needed
- Copies public key to all nodes
- Enables passwordless SSH
- Tests connectivity

**Duration:** ~1 minute

**Verify:**
```bash
ansible -i inventory/production.yml all -m ping
```

**Expected output:**
```text
node0.yourdomain.com | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
...
```

---

### Step 2: Validate Prerequisites

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/validate-prerequisites.yml
```

**What it checks:**
- Network connectivity
- SSH access
- Sudo privileges
- System resources (RAM, disk)
- Python version
- Required ports available

**Duration:** ~30 seconds

**If validation fails:**
- Check inventory hostnames/IPs
- Verify SSH keys distributed
- Ensure sudo configured
- Check firewall rules

---

### Step 3: System Preparation

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/setup-common.yml
```

**What it does:**

1. **Install Packages:**
   - curl, apt-transport-https, ca-certificates
   - software-properties-common
   - docker.io
   - socat, conntrack, ipset (K3s dependencies)

2. **Load Kernel Modules:**
   - br_netfilter (bridge networking)
   - overlay (container filesystems)
   - ip_vs, ip_vs_rr, ip_vs_wrr, ip_vs_sh (load balancing)

3. **Configure Sysctl:**
   - Enable IP forwarding
   - Configure bridge networking
   - Set connection tracking

4. **System Configuration:**
   - Disable swap
   - Configure /etc/hosts
   - Set timezone

**Duration:** ~3-5 minutes

**Verify:**
```bash
# Check kernel modules
ansible -i inventory/production.yml all -m shell -a "lsmod | grep br_netfilter"

# Check sysctl
ansible -i inventory/production.yml all -m shell -a "sysctl net.ipv4.ip_forward"
# Should return: net.ipv4.ip_forward = 1
```

---

### Step 4: Deploy K3s Cluster

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/deploy-k3s.yml
```

**What it does:**

**First Master (node0):**
1. Download K3s installation script
2. Install K3s with `--cluster-init` flag (HA mode)
3. Start K3s service
4. Retrieve node token
5. Save kubeconfig

**Additional Masters (if HA):**
1. Join cluster with `--server` flag
2. Use embedded etcd for HA
3. Verify join successful

**Agent Nodes:**
1. Join cluster as workers
2. Connect to all master nodes
3. Verify node ready

**Duration:** ~5-10 minutes

**Verify:**
```bash
# SSH to node0
ssh node0

# Check cluster nodes
kubectl get nodes

# Expected output:
# NAME                    STATUS   ROLES                       AGE     VERSION
# node0.yourdomain.com    Ready    control-plane,etcd,master   5m      v1.28.x+k3s1
# node1.yourdomain.com    Ready    control-plane,etcd,master   4m      v1.28.x+k3s1
# node2.yourdomain.com    Ready    control-plane,etcd,master   4m      v1.28.x+k3s1
# node3.yourdomain.com    Ready    <none>                      3m      v1.28.x+k3s1
# ...

# Check system pods
kubectl get pods -A

# All should be Running
```

---

### Step 5: Deploy Rancher (Optional)

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/deploy-rancher.yml
```

**What it does:**
- Installs cert-manager for certificate management
- Deploys Rancher management UI
- Provides web-based cluster administration
- Enables monitoring and visualization

**Duration:** ~5-10 minutes

**Access:**
```text
https://rancher.yourdomain.com  # or configured hostname
```

**Setup:**
1. Navigate to Rancher URL
2. Set admin password on first access
3. Rancher auto-detects local K3s cluster

:::tip Why Rancher?
Provides invaluable visibility: pod logs, resource usage, deployment status, and troubleshooting tools.
:::

---

### Step 6: Deploy Longhorn Storage (Required)

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/deploy-longhorn.yml
```

**What it does:**
- Deploys Longhorn distributed block storage
- Removes master node taints to enable scheduling on all nodes
- Disables default disk, uses `/mnt/longhorn` on all nodes
- Creates StorageClass `longhorn` (set as default)
- Configures 3 replicas for high availability
- Monitors deployment with real-time progress

**Duration:** ~3-5 minutes

**Verify:**
```bash
ssh node0

# Check Longhorn pods
kubectl get pods -n longhorn-system

# All pods should be Running (managers, UI, CSI components)

# Check storage class
kubectl get storageclass

# Expected:
# NAME                 PROVISIONER          RECLAIMPOLICY   ...
# longhorn (default)   driver.longhorn.io   Delete          ...

# Access Longhorn UI
http://node0:30630  # or any node IP
```

:::warning Deploy Before Applications
**Longhorn must be deployed before registry and OpenTAK Server** as they require persistent storage volumes. This playbook ensures all nodes can schedule Longhorn workloads by removing CriticalAddonsOnly taints from master nodes.
:::

---

### Step 7: Deploy Docker Registry

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/deploy-registry.yml
```

**What it does:**

**On Primary Master (node0):**
1. Start Docker registry container on port 5000
2. Persist images to `/var/lib/registry`
3. Enable restart always

**On All Nodes:**
1. Create `/etc/rancher/k3s/registries.yaml`
2. Configure insecure registry access
3. Restart K3s service
4. Verify registry accessible

**Duration:** ~2 minutes

**Verify:**
```bash
# Test registry API
curl -I http://node0:5000/v2/

# Expected: HTTP/1.1 200 OK

# Check registry container
ssh node0
docker ps | grep registry

# Should show running registry:2 container
```

---

### Step 8: Deploy OpenTAKServer

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Prompt:** Enter sudo password when asked (for Docker daemon config)

**What it does:**

1. **Configure Docker:**
   - Adds insecure registry to `/etc/docker/daemon.json`
   - Restarts Docker daemon

2. **Clone Repository:**
   - Clones arclink to node0
   - Pulls latest changes

3. **Build OpenTAKServer with Socket.IO Patches:**
   - Auto-detects Python version (3.11, 3.12, 3.13)
   - Applies patches to `extensions.py`:
     - Enables CORS: `cors_allowed_origins='*'`
     - Removes RabbitMQ message_queue
     - Increases ping timeout to 60 seconds
   - Builds image: `node0:5000/opentakserver:1.6.3`
   - Uses Docker layer cache for speed

4. **Build UI Image:**
   - nginx with WebSocket proxy configuration
   - Builds image: `node0:5000/ui:latest`

5. **Push to Registry:**
   - Pushes both images to local registry
   - Makes available to all cluster nodes

6. **Deploy to Kubernetes:**
   - Deletes existing deployment (if any)
   - Creates namespace `tak`
   - Deploys PostgreSQL
   - Deploys RabbitMQ
   - Deploys OpenTAKServer with custom images
   - Waits for all pods to be ready

7. **Verify Patches:**
   - Checks running container for patches
   - Confirms CORS enabled

**Duration:**
- First run: ~30 minutes (building images)
- Subsequent: ~3-5 minutes (Docker cache)

**Verify:**
```bash
ssh node0

# Check pods
kubectl get pods -n tak

# Expected:
# NAME                             READY   STATUS    RESTARTS   AGE
# opentakserver-xxxxxxxxxx-xxxxx   2/2     Running   0          2m
# postgres-xxxxxxxxxx-xxxxx        1/1     Running   0          2m
# rabbitmq-xxxxxxxxxx-xxxxx        1/1     Running   0          2m

# Verify Socket.IO patches
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  python3 -c "import opentakserver.extensions; print('✅ Patches verified!' if hasattr(opentakserver.extensions.socketio, 'cors_allowed_origins') else '❌ No patches')"

# Check WebSocket logs (should see HTTP 200)
kubectl logs -n tak ${POD} -c nginx --tail=50 | grep socket.io
```

---

### Step 9: Validate Deployment

**📍 Location: Control Node**

```bash
ansible-playbook playbooks/validate-k3s-cluster.yml
```

**What it checks:**
- All nodes Ready
- System pods running
- Longhorn healthy
- Registry accessible
- API server responsive
- Application pods running

**Duration:** ~30 seconds

---

## Access Your Deployment

### Web UI

```text
http://node0:31080
```

Or use IP address:
```text
http://192.168.1.100:31080
```

### Default Credentials

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

**Expected:** `✅ WebSocket connected!`

---

## Common Workflows

### Update OpenTAKServer

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Duration:** ~3-5 minutes (Docker cache)

---

### Reset and Redeploy

```bash
# Complete teardown
ansible-playbook playbooks/reset-cluster.yml
# Type 'yes' when prompted

# Redeploy (skip bootstrap if SSH keys still work)
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Duration:** ~15 minutes (with Docker cache)

---

### Add New Agent Node

1. **Update inventory:**
   ```yaml
   k3s_agents:
     hosts:
       # ... existing nodes ...
       node7.yourdomain.com:
         ansible_host: 192.168.1.107
   ```

2. **Bootstrap and deploy:**
   ```bash
   ansible-playbook playbooks/bootstrap.yml --limit=node7 --ask-pass
   ansible-playbook playbooks/setup-common.yml --limit=node7
   ansible-playbook playbooks/deploy-k3s.yml --limit=node7
   ```

3. **Verify:**
   ```bash
   ssh node0
   kubectl get nodes
   # Should see node7 in Ready state
   ```

---

### Remove Node

```bash
# SSH to node0
ssh node0

# Drain node (move workloads)
kubectl drain node7.yourdomain.com --delete-emptydir-data --force --ignore-daemonsets

# Delete from cluster
kubectl delete node node7.yourdomain.com

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

# Verify sysctl settings
sysctl -a | grep -E '(ip_forward|bridge)'
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
# - Insufficient resources: Check node resources with kubectl top nodes
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
  -a "curl -I http://node0:5000/v2/"

# Check K3s registry config
cat /etc/rancher/k3s/registries.yaml

# Check Docker daemon config
cat /etc/docker/daemon.json

# Restart services
sudo systemctl restart docker
sudo systemctl restart k3s
```

---

### Socket.IO Not Working

```bash
ssh node0

# Verify patches applied
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  grep "cors_allowed_origins" /app/venv/lib/python*/site-packages/opentakserver/extensions.py

# Should see: cors_allowed_origins='*',

# Check nginx proxy config
kubectl exec -n tak ${POD} -c nginx -- cat /etc/nginx/nginx.conf | grep -A 10 socket.io

# Check WebSocket logs
kubectl logs -n tak ${POD} -c nginx --tail=100 | grep socket.io

# Should see HTTP 200, not 400 errors
```

---

### Docker Build Fails

```bash
# Clear cache and rebuild
ssh node0
docker system prune -af  # Warning: removes all unused data

# Rebuild from control node
cd ~/arclink/ansible
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

---

## What You've Accomplished

✅ **High Availability K3s Cluster** - With embedded etcd  
✅ **Distributed Storage** - Longhorn with 3 replicas  
✅ **Local Registry** - Private Docker registry  
✅ **OpenTAKServer** - With working WebSocket support  
✅ **Complete Automation** - Reproducible deployments  

Your infrastructure is production-ready! 🎉

---

## Next Steps

- **[Quick Start](./quickstart.md)** - Fast deployment reference
- **[Ansible Overview](./ansible/overview.md)** - Deep dive into automation
- **[Configuration](./configuration.md)** - Customize settings
- **[Troubleshooting](./troubleshooting.md)** - Additional help
- **[High Availability](./ansible/high-availability.md)** - HA configuration details
