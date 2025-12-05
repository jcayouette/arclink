---
# Ansible Prerequisites Setup Guide

This guide helps you prepare your environment before running Ansible playbooks.

## 1. Control Node Setup (Your Workstation/WSL)

### Install Ansible
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# Verify installation
ansible --version
```

### Install Required Collections
```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.general
```

## 2. SSH Key Setup (Automated)

Ansible will handle SSH key generation and distribution automatically!

### Run Bootstrap Playbook
```bash
cd ansible/

# This will prompt for your cluster node password once
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

The bootstrap playbook will:
- Generate SSH key if you don't have one (~/.ssh/id_ed25519)
- Copy the key to all nodes in your inventory
- Verify passwordless SSH access
- Display a summary

**Note:** You'll be prompted for the password once. This is the password you use to SSH into your cluster nodes.

## 3. Inventory Configuration

### Copy and Edit Inventory
```bash
cd ansible/
cp inventory/production.yml inventory/my-cluster.yml
```

### Update for Your Environment
Edit `inventory/my-cluster.yml`:

```yaml
all:
  vars:
    ansible_user: YOUR_USERNAME        # Change this
    domain: YOUR_DOMAIN                # Change this
    registry_host: YOUR_MASTER_NODE    # Change this
    
  children:
    k3s_cluster:
      children:
        k3s_master:
          hosts:
            YOUR_MASTER_HOSTNAME:      # Change this
              ansible_host: YOUR_MASTER_IP
        
        k3s_agents:
          hosts:
            YOUR_AGENT1_HOSTNAME:      # Change this
              ansible_host: YOUR_AGENT1_IP
            # Add more agents as needed
```

## 4. Passwordless Sudo Setup

Ansible needs passwordless sudo on all nodes. On each cluster node, run:

```bash
# Create sudoers file for your user
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER

# Set proper permissions
sudo chmod 440 /etc/sudoers.d/$USER

# Verify
sudo whoami  # Should not ask for password
```

Or use the provided script (from master node):
```bash
# On each agent node
./scripts/helpers/setup-ssh-keys.sh  # This also configures sudo
```

## 5. Network/DNS Configuration

### Option A: Use /etc/hosts
Add entries on your control node:
```bash
sudo tee -a /etc/hosts << EOF
10.0.0.160  node0.yourdomain.local
10.0.0.161  node1.yourdomain.local
10.0.0.162  node2.yourdomain.local
# Add all your nodes
EOF
```

### Option B: Use ansible_host in Inventory
Already done if you followed step 3 and included `ansible_host` for each node.

## 6. Verify Prerequisites

### Test Ansible Connectivity
```bash
cd ansible/
ansible -i inventory/my-cluster.yml all -m ping
```

Expected output:
```
node0.yourdomain | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
# ... all nodes should respond
```

### Test Sudo Access
```bash
ansible -i inventory/my-cluster.yml all -m command -a "sudo whoami" --become
```

Expected output: `root` for all nodes without password prompts.

### Verify Group Structure
```bash
ansible-inventory -i inventory/my-cluster.yml --list
ansible-inventory -i inventory/my-cluster.yml --graph
```

## 7. Common Issues

### "Permission denied (publickey)"
- SSH keys not copied to nodes
- Run `ssh-copy-id user@node` for each node
- Or use `./scripts/helpers/setup-ssh-keys.sh`

### "Missing sudo password"
- Passwordless sudo not configured
- Follow step 4 above on each node

### "No inventory was parsed"
- Wrong directory (must be in `ansible/` folder)
- Or specify inventory: `ansible -i inventory/my-cluster.yml`

### "Could not resolve hostname"
- DNS not configured
- Add entries to `/etc/hosts` or use `ansible_host` in inventory

## 8. Quick Start Workflow

### Step 1: Install Ansible
```bash
sudo apt update && sudo apt install -y ansible
ansible-galaxy collection install kubernetes.core community.docker community.general
```

### Step 2: Configure Inventory
```bash
cd ansible/
cp inventory/production.yml inventory/my-cluster.yml
vim inventory/my-cluster.yml  # Update IPs, hostnames, usernames
```

### Step 3: Bootstrap SSH Access
```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

### Step 4: Validate Prerequisites
```bash
ansible-playbook playbooks/validate-prerequisites.yml
```

### Step 5: Setup Cluster
```bash
ansible-playbook playbooks/setup-common.yml
```

## Quick Start Checklist

- [ ] Ansible installed on control node
- [ ] Required collections installed
- [ ] Inventory file customized (`inventory/my-cluster.yml`)
- [ ] Bootstrap playbook run (SSH keys distributed)
- [ ] Validation playbook passed
- [ ] Ready for cluster deployment

## Deployment Phases

After completing prerequisites, deploy your cluster in phases:

### Phase 1: System Preparation
```bash
ansible-playbook playbooks/setup-common.yml
```

This configures all nodes with:
- Required packages (curl, wget, socat, conntrack)
- Kernel modules (br_netfilter, overlay)
- System settings (IP forwarding, bridge netfilter)
- /etc/hosts entries for all nodes
- Disabled swap

### Phase 2: Docker Registry
```bash
ansible-playbook playbooks/deploy-registry.yml
```

This sets up:
- Docker installation on primary master
- Local registry container on port 5000
- Registry configuration on all nodes (/etc/rancher/k3s/registries.yaml)

### Phase 3: K3s Cluster
```bash
ansible-playbook playbooks/deploy-k3s.yml
```

This deploys:
- K3s masters with embedded etcd (HA mode if 3+ masters)
- K3s agents joining the cluster
- Kubeconfig saved to `ansible/kubeconfig`

### Verify Deployment
```bash
# Use kubeconfig from ansible directory
export KUBECONFIG=~/arclink/ansible/kubeconfig
kubectl get nodes

# Or SSH to master
ssh acmeastro@node0.research.core
sudo k3s kubectl get nodes
```

## Cluster Topologies

### Single Node (Development)
- 1 master node
- No HA, simplest setup

### Three Nodes (HA - Recommended)
- 3 master nodes with embedded etcd
- True high availability
- Survives 1 node failure

### Large Cluster (7+ nodes)
- 3 master nodes (HA control plane)
- 4+ agent nodes (workers)
- Best for production workloads

See `inventory/production.yml` for our 7-node reference implementation.

## Next Steps

After cluster deployment:
1. Install Longhorn for distributed storage
2. Deploy Rancher for cluster management (optional)
3. Deploy OpenTAKServer application
4. Configure TLS certificates

See the [progress checklist](../../docs/docs/guides/ansible/progress-checklist.md) for detailed implementation status.

## Reference

- Your cluster uses: `{{ ansible_user }}` as the remote user
- Control node runs from: Your workstation/WSL
- Inventory path: `ansible/inventory/`
- Playbooks path: `ansible/playbooks/`
- Roles path: `ansible/roles/`

### Available Playbooks
- `bootstrap.yml` - SSH key distribution
- `validate-prerequisites.yml` - Verify cluster readiness
- `setup-common.yml` - System preparation
- `deploy-registry.yml` - Docker registry setup
- `deploy-k3s.yml` - K3s cluster deployment

### Available Roles
- `common` - System configuration for K3s
- `docker-registry` - Local registry for custom images
- `k3s-master` - K3s control plane with HA support
- `k3s-agent` - K3s worker nodes
