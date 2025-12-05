---
sidebar_position: 0
---

# Ansible Automation Overview

:::tip Fully Implemented
Complete Ansible automation for OpenTAKServer deployment on K3s clusters is now available! Deploy entire infrastructure with a few commands.
:::

## Overview

Ansible provides comprehensive automation for deploying and managing OpenTAKServer on K3s clusters running Ubuntu 24.04 LTS. From bare metal to running application in minutes.

**Tested Configuration:** 7-node Raspberry Pi 5 cluster (3 masters + 4 agents) with High Availability

## What's Automated

- ✅ **SSH key distribution** - Passwordless authentication
- ✅ **System preparation** - Kernel modules, parameters, packages
- ✅ **K3s cluster deployment** - HA with embedded etcd
- ✅ **Docker registry** - Local registry for custom images
- ✅ **Longhorn storage** - Distributed persistent storage
- ✅ **Rancher management** - Optional cluster UI
- ✅ **OpenTAKServer deployment** - With Socket.IO patches
- ✅ **Validation & verification** - Automated health checks
- ✅ **Cluster reset** - Clean uninstall for fresh starts

## Quick Start

```bash
# From your control node (WSL/workstation)
cd ~/arclink/ansible

# Deploy everything
ansible-playbook playbooks/bootstrap.yml --ask-pass
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml

# Deploy OpenTAKServer with Socket.IO patches
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Access:** `http://node0:31080` (or your master node IP/hostname)

## Key Features

### Declarative Infrastructure
- **Idempotent operations** - Safe to run multiple times
- **Parallel execution** - Configure all nodes simultaneously
- **Configuration templating** - Jinja2 for dynamic values
- **Built-in error handling** - Automatic retry and rollback

### Complete Lifecycle Management
- **Bootstrap** - Initial SSH setup and authentication
- **Deploy** - Full stack from OS to application
- **Update** - Rolling updates with zero downtime
- **Reset** - Complete cluster teardown and cleanup
- **Validate** - Comprehensive health checks

### Production Ready
- **High Availability** - 3+ master nodes with embedded etcd
- **Distributed Storage** - Longhorn across all nodes
- **Custom Images** - Local registry with Socket.IO patches
- **Security** - SSH keys, sudoers configuration

## Architecture

```
ansible/
├── inventory/
│   ├── production.yml           # Production cluster inventory
│   └── group_vars/
│       ├── all.yml              # Global variables (registry, versions)
│       ├── k3s_master.yml       # Master node configuration
│       └── k3s_agents.yml       # Agent node configuration
├── playbooks/
│   ├── bootstrap.yml            # SSH key distribution
│   ├── setup-common.yml         # System preparation
│   ├── validate-prerequisites.yml # Pre-flight checks
│   ├── deploy-k3s.yml           # K3s HA cluster
│   ├── deploy-longhorn.yml      # Distributed storage
│   ├── deploy-registry.yml      # Docker registry
│   ├── deploy-rancher.yml       # Rancher UI (optional)
│   ├── build-docker-images.yml  # Build custom images
│   ├── deploy-opentakserver.yml # Deploy OTS
│   ├── deploy-opentakserver-with-patches.yml # OTS with Socket.IO
│   ├── reset-cluster.yml        # Complete teardown
│   └── validate-k3s-cluster.yml # Post-deploy validation
├── roles/
│   ├── common/                  # System packages, kernel config
│   ├── k3s-master/              # K3s master with etcd
│   ├── k3s-agent/               # K3s agent nodes
│   ├── docker-registry/         # Registry deployment
│   └── docker-build/            # Image building with patches
└── README.md                    # Complete documentation
```

## Available Playbooks

### Infrastructure Playbooks

#### `bootstrap.yml` - SSH Key Distribution
**Purpose:** Setup passwordless SSH authentication  
**Run Once:** Initial setup only  
**Usage:** `ansible-playbook playbooks/bootstrap.yml --ask-pass`

**What it does:**
- Creates SSH key pair if needed
- Distributes public key to all nodes
- Enables passwordless authentication
- No need to enter passwords for subsequent playbooks

---

#### `setup-common.yml` - System Preparation
**Purpose:** Configure OS for K3s  
**Hosts:** All cluster nodes  
**Usage:** `ansible-playbook playbooks/setup-common.yml`

**What it does:**
- Installs required packages (curl, apt-transport-https, etc.)
- Loads kernel modules (br_netfilter, overlay, ip_vs)
- Configures sysctl parameters (IP forwarding, bridge settings)
- Sets timezone and hostname resolution
- Updates system packages

---

#### `deploy-k3s.yml` - K3s Cluster Deployment
**Purpose:** Deploy high-availability K3s cluster  
**Duration:** ~5-10 minutes  
**Usage:** `ansible-playbook playbooks/deploy-k3s.yml`

**What it does:**
- Installs K3s on first master with embedded etcd
- Joins additional masters to HA cluster
- Joins agent nodes to cluster
- Configures kubectl on master nodes
- Validates cluster health

**Requirements:** `setup-common.yml` must be run first

---

#### `deploy-longhorn.yml` - Distributed Storage
**Purpose:** Deploy Longhorn for persistent volumes  
**Duration:** ~2-3 minutes  
**Usage:** `ansible-playbook playbooks/deploy-longhorn.yml`

**What it does:**
- Deploys Longhorn system to cluster
- Creates storage class for dynamic provisioning
- Configures 3 replicas for data redundancy
- Waits for Longhorn pods to be ready

---

#### `deploy-registry.yml` - Local Docker Registry
**Purpose:** Setup private registry for custom images  
**Duration:** ~2 minutes  
**Usage:** `ansible-playbook playbooks/deploy-registry.yml`

**What it does:**
- Deploys registry as Docker container on node0
- Exposes on port 5000
- Persists images to `/var/lib/registry`
- Configures K3s and Docker to trust registry

---

### Application Playbooks

#### `deploy-opentakserver-with-patches.yml` - Full Deployment
**Purpose:** Build and deploy OpenTAKServer with Socket.IO fixes  
**Duration:** ~30 min (first run), ~3-5 min (cached)  
**Usage:** `ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass`

**What it does:**
- Configures Docker for insecure registry
- Clones arclink repository
- Builds OpenTAKServer image with Socket.IO patches:
  - Enables CORS (`cors_allowed_origins='*'`)
  - Removes RabbitMQ message_queue
  - Increases ping timeout to 60 seconds
- Builds UI image with nginx
- Pushes images to local registry
- Deploys to K3s namespace `tak`
- Waits for pods to be ready
- Verifies patches in running container

**Socket.IO Patches Applied:**
```python
# Automatically applied to extensions.py
socketio = SocketIO(
    app, 
    cors_allowed_origins='*',  # CORS enabled
    async_mode='gevent_uwsgi',
    # message_queue removed        # RabbitMQ queue removed
    ping_timeout=60,             # Timeout increased
    ping_interval=25
)
```

---

### Utility Playbooks

#### `validate-prerequisites.yml` - Pre-flight Checks
**Purpose:** Verify system requirements  
**Usage:** `ansible-playbook playbooks/validate-prerequisites.yml`

**Validates:**
- SSH connectivity
- User permissions
- Required ports available
- Minimum system resources
- Python version

---

#### `validate-k3s-cluster.yml` - Post-deployment Checks
**Purpose:** Verify K3s cluster health  
**Usage:** `ansible-playbook playbooks/validate-k3s-cluster.yml`

**Validates:**
- All nodes are Ready
- System pods running
- Longhorn healthy
- Registry accessible
- API server responsive

---

#### `reset-cluster.yml` - Complete Teardown
**Purpose:** Uninstall everything for fresh start  
**Duration:** ~2-3 minutes  
**Usage:** `ansible-playbook playbooks/reset-cluster.yml`  
**Confirmation:** Type `yes` when prompted

**What it does:**
- Uninstalls K3s from all nodes
- Removes Docker and configurations
- Cleans persistent data
- Removes Rancher, Longhorn, applications
- Preserves: kernel modules, /etc/hosts, SSH keys

## Inventory Example

```yaml
# inventory/production.yml
all:
  vars:
    ansible_user: acmeastro
    ansible_become: yes
    registry_address: "node0.research.core:5000"
    ots_version: "1.6.3"
    
  children:
    k3s_cluster:
      children:
        k3s_master:
          hosts:
            node0.research.core:
              ansible_host: 10.0.0.160
              
        k3s_agents:
          hosts:
            node1.research.core:
              ansible_host: 10.0.0.161
            node2.research.core:
              ansible_host: 10.0.0.162
            node3.research.core:
              ansible_host: 10.0.0.163
            node4.research.core:
              ansible_host: 10.0.0.164
            node5.research.core:
              ansible_host: 10.0.0.165
            node6.research.core:
              ansible_host: 10.0.0.166
```

## Usage

### Initial Setup
```bash
# Setup entire cluster from scratch
ansible-playbook -i inventory/production.yml playbooks/site.yml

# Or step by step:
ansible-playbook -i inventory/production.yml playbooks/setup-cluster.yml
ansible-playbook -i inventory/production.yml playbooks/setup-registry.yml
ansible-playbook -i inventory/production.yml playbooks/deploy-app.yml
```

### Updates
```bash
# Update application only
ansible-playbook -i inventory/production.yml playbooks/deploy-app.yml

# Update registry configuration
ansible-playbook -i inventory/production.yml playbooks/setup-registry.yml
```

### Rollback
```bash
# Rollback to previous version
ansible-playbook -i inventory/production.yml playbooks/rollback.yml
```

## Deployment Workflows

### Fresh Installation (Bare Metal to Running App)

```bash
# 1. Bootstrap SSH access
ansible-playbook playbooks/bootstrap.yml --ask-pass

# 2. Prepare systems
ansible-playbook playbooks/validate-prerequisites.yml
ansible-playbook playbooks/setup-common.yml

# 3. Deploy infrastructure
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml

# 4. Deploy application
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass

# 5. Validate
ansible-playbook playbooks/validate-k3s-cluster.yml
```

**Total Time:** ~45 minutes (first run with image builds)

---

### Reset and Redeploy

```bash
# 1. Complete teardown
ansible-playbook playbooks/reset-cluster.yml  # Type 'yes' to confirm

# 2. Quick redeploy (already bootstrapped)
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Total Time:** ~15 minutes (with Docker cache)

---

### Update OpenTAKServer Only

```bash
# Rebuild and redeploy application
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Total Time:** ~3-5 minutes (Docker cache)

---

### Add/Remove Nodes

Edit `inventory/production.yml`, then:

```bash
# Add new agent node
ansible-playbook playbooks/setup-common.yml --limit=new_node
ansible-playbook playbooks/deploy-k3s.yml --limit=new_node

# Remove node
kubectl drain node-name --delete-emptydir-data --force --ignore-daemonsets
kubectl delete node node-name
```

## Benefits of Ansible Approach

| Feature | Manual/Scripts | Ansible |
|---------|---------------|---------|
| **Execution** | Sequential | Parallel across nodes |
| **Idempotency** | Manual checks | Built-in |
| **Error Recovery** | Start over | Auto-retry, rollback |
| **Configuration** | sed/awk/env files | Jinja2 templates |
| **Validation** | Manual | Automated pre/post checks |
| **Dry Run** | Not available | `--check` mode |
| **Logging** | Basic stdout | Structured output |
| **Secrets** | Plain text files | Ansible Vault support |
| **Scaling** | Loop over nodes | Inventory-driven |
| **State Tracking** | None | Playbook success/failure |

## Prerequisites

### Control Node (Where you run Ansible)
- ✅ Ansible 2.9+ installed
- ✅ Python 3.8+
- ✅ SSH client
- ✅ Network access to cluster nodes

**Install Ansible:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# macOS
brew install ansible

# Required collections
ansible-galaxy collection install kubernetes.core community.docker community.general
```

### Cluster Nodes
- ✅ Ubuntu Server 24.04 LTS
- ✅ SSH access enabled
- ✅ Python 3 (included in Ubuntu)
- ✅ Passwordless sudo (configured by bootstrap playbook)
- ✅ Minimum 4GB RAM per node
- ✅ Minimum 32GB storage per node

## Configuration

### Inventory Setup

Edit `ansible/inventory/production.yml`:

```yaml
all:
  vars:
    ansible_user: yourusername
    ansible_become: yes
    registry_address: "node0.your.domain:5000"
    ots_version: "1.6.3"
    
  children:
    k3s_cluster:
      children:
        k3s_master:
          hosts:
            node0.your.domain:
              ansible_host: 10.0.0.160
            # Add more masters for HA (must be odd number: 3, 5, 7)
            
        k3s_agents:
          hosts:
            node1.your.domain:
              ansible_host: 10.0.0.161
            node2.your.domain:
              ansible_host: 10.0.0.162
            # Add more agents as needed
```

### Variable Overrides

Override defaults with `-e`:

```bash
# Different OTS version
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml \
  -e "ots_version=1.6.4" \
  --ask-become-pass

# Different registry
ansible-playbook playbooks/deploy-registry.yml \
  -e "registry_address=registry.example.com:5000"

# Different namespace
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml \
  -e "namespace=production" \
  --ask-become-pass
```

## Troubleshooting

### Check Connectivity
```bash
# Ping all nodes
ansible -i inventory/production.yml all -m ping

# Check sudo access
ansible -i inventory/production.yml all -m shell -a "whoami" --become
```

### Verbose Output
```bash
# Increase verbosity
ansible-playbook playbooks/deploy-k3s.yml -v    # Basic
ansible-playbook playbooks/deploy-k3s.yml -vv   # More details
ansible-playbook playbooks/deploy-k3s.yml -vvv  # Debug level
```

### Dry Run
```bash
# Check what would change
ansible-playbook playbooks/deploy-k3s.yml --check
```

### Target Specific Nodes
```bash
# Run on subset of nodes
ansible-playbook playbooks/setup-common.yml --limit=node0,node1

# Run on specific group
ansible-playbook playbooks/deploy-k3s.yml --limit=k3s_master
```

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [K3s Ansible Examples](https://github.com/k3s-io/k3s-ansible)
- [Kubernetes Ansible Collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [Ansible README](https://github.com/jcayouette/arclink/blob/main/ansible/README.md)
