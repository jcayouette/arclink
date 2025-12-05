---
sidebar_position: 3
---

# Playbook Reference

Complete reference for all available Ansible playbooks.

## Bootstrap & Setup

### `bootstrap.yml`

**Purpose:** Setup SSH key-based authentication  
**Run Once:** Initial setup only  
**Requires:** SSH password access

```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

**Tasks:**
1. Check for existing SSH key
2. Generate new SSH key if needed
3. Copy public key to all cluster nodes
4. Enable passwordless authentication
5. Test SSH connectivity

**Variables:**
- `ansible_user` - SSH username (from inventory)

**When to use:**
- First time setting up a new cluster
- After reinstalling nodes
- When adding new nodes

---

### `remove-ssh-keys.yml`

**Purpose:** Remove SSH keys from cluster nodes (for testing bootstrap)
**Duration:** ~30 seconds  
**Requires:** Current passwordless SSH access

```bash
ansible-playbook playbooks/remove-ssh-keys.yml
```

**Tasks:**
1. Confirm action with user prompt
2. Backup authorized_keys on all nodes (timestamped)
3. Clear authorized_keys files (removes SSH keys)
4. Verify passwordless SSH is disabled
5. Display restoration instructions

**What it does:**
- Removes SSH public keys from `~/.ssh/authorized_keys`
- Backs up existing keys before removal
- **Does NOT disable SSH service** - SSH still runs
- Only removes passwordless key-based access

**When to use:**
- Testing bootstrap process from scratch
- Preparing for clean SSH key rotation
- Verifying bootstrap playbook works correctly

**Warning:** This removes passwordless SSH keys! You must run `bootstrap.yml --ask-pass` to restore key-based access.

**Restore access:**
```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

---

### `disable-password-auth.yml`

**Purpose:** Disable SSH password authentication for security  
**Duration:** ~30 seconds  
**Requires:** Bootstrap completed with SSH keys working

```bash
ansible-playbook playbooks/disable-password-auth.yml
```

**Tasks:**
1. **Test SSH key-based authentication on ALL nodes**
   - Uses `ssh -o PreferredAuthentications=publickey` (keys only, no passwords)
   - Verifies each node individually
2. Fail with clear instructions if any node doesn't have working keys
3. Disable PasswordAuthentication in sshd_config
4. Disable ChallengeResponseAuthentication
5. Disable PAM authentication
6. Restart SSH service
7. Verify key-based auth still works

**Built-in Safety:**
- Tests actual key-based authentication (not just SSH connectivity)
- Prevents lockouts from nodes with missing/broken keys
- Shows which specific nodes failed verification
- Fails gracefully with recovery instructions
- No manual verification needed

**Security benefits:**
- Prevents brute-force password attacks
- Only SSH keys can authenticate
- Production security best practice
- Required for secure deployments

**When to use:**
- **IMMEDIATELY after bootstrap** (critical security step)
- Before exposing nodes to network
- As part of initial cluster setup

**If it fails:**
The playbook will instruct you to re-run bootstrap:
```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

**Warning:** After this, you MUST use SSH keys. Keep your private key (`~/.ssh/id_ed25519`) safe!

---

### `enable-password-auth.yml`

**Purpose:** Re-enable SSH password authentication (for recovery)
**Duration:** ~30 seconds  
**Requires:** SSH key access to nodes

```bash
ansible-playbook playbooks/enable-password-auth.yml
```

**Tasks:**
1. Prompt for confirmation (type 'yes' to proceed)
2. Enable PasswordAuthentication in sshd_config
3. Enable ChallengeResponseAuthentication
4. Enable PAM authentication
5. Restart SSH service
6. Display security warning

**When to use:**
- **Recovery scenarios** when SSH keys are lost or corrupted
- Temporary password access for troubleshooting
- Adding new administrators who need initial access
- Testing or training environments

**Security implications:**
- ⚠️ **REDUCES security** - allows password brute-force attacks
- Should only be used temporarily
- SSH keys continue to work (recommended)
- Disable password auth again when done

**Recovery workflow (if you still have SSH access):**
```bash
# 1. Re-enable password authentication
ansible-playbook playbooks/enable-password-auth.yml

# 2. Do your recovery work (fix keys, add new admins, etc.)

# 3. Disable password authentication again
ansible-playbook playbooks/disable-password-auth.yml
```

**If you lost SSH keys AND password auth is disabled:**

You'll need physical or console access (IPMI/iLO/KVM) to manually re-enable password authentication on each node:

```bash
# On each node (via console/IPMI):
sudo nano /etc/ssh/sshd_config

# Change to:
PasswordAuthentication yes

# Restart SSH
sudo systemctl restart ssh

# Then from control node:
ansible-playbook playbooks/bootstrap.yml --ask-pass
ansible-playbook playbooks/disable-password-auth.yml
```

**Prevention is key:** Always keep backups of your SSH private key in a secure location!

**Warning:** Production systems should always have password authentication disabled except during recovery operations!

---

### `setup-common.yml`

**Purpose:** Prepare all nodes for K3s  
**Duration:** ~3-5 minutes  
**Requires:** Bootstrap completed

```bash
ansible-playbook playbooks/setup-common.yml
```

**Tasks:**
1. Update apt cache
2. Install required packages (curl, ca-certificates, etc.)
3. Install K3s dependencies (socat, conntrack, ipset)
4. Load kernel modules (br_netfilter, overlay, ip_vs)
5. Configure modules to load on boot
6. Set sysctl parameters (IP forwarding, bridge settings)
7. Disable swap
8. Configure /etc/hosts with cluster nodes

**Variables:**
- `common_packages` - Package list (from role defaults)
- `k3s_required_modules` - Kernel modules (from role defaults)

**When to use:**
- After bootstrap on new nodes
- Before deploying K3s
- After OS updates that may have reset settings

---

### `validate-prerequisites.yml`

**Purpose:** Verify system readiness for K3s  
**Duration:** ~30 seconds  
**Safe to run anytime**

```bash
ansible-playbook playbooks/validate-prerequisites.yml
```

**Checks:**
- SSH connectivity to all nodes
- Passwordless sudo configured
- Python 3 installed
- Minimum system resources (RAM, disk)
- Required ports available (6443, 10250, etc.)
- Network connectivity between nodes

**When to use:**
- Before deploying K3s
- Troubleshooting connectivity issues
- Verifying new node configuration

---

## Infrastructure Deployment

### `deploy-k3s.yml`

**Purpose:** Deploy High Availability K3s cluster  
**Duration:** ~5-10 minutes  
**Requires:** `setup-common.yml` completed

```bash
ansible-playbook playbooks/deploy-k3s.yml
```

**Tasks:**

**On First Master (node0):**
1. Download K3s install script
2. Install K3s with `--cluster-init` (HA mode)
3. Start K3s service
4. Retrieve node token
5. Save kubeconfig

**On Additional Masters (node1, node2):**
1. Download K3s install script
2. Join cluster with `--server` flag
3. Use embedded etcd for HA
4. Verify join successful

**On Agent Nodes (node3-6):**
1. Download K3s install script
2. Join cluster as agent
3. Connect to all master nodes
4. Verify node ready

**Variables:**
- `k3s_version` - K3s version to install
- `k3s_master_flags` - Master node flags (from group_vars)
- `k3s_agent_flags` - Agent node flags (from group_vars)

**When to use:**
- Initial cluster deployment
- After cluster reset
- When adding new nodes (with --limit)

---

### `deploy-longhorn.yml`

**Purpose:** Deploy distributed storage  
**Duration:** ~2-3 minutes  
**Requires:** K3s cluster running

```bash
ansible-playbook playbooks/deploy-longhorn.yml
```

**Tasks:**
1. Apply Longhorn deployment manifest
2. Wait for Longhorn namespace creation
3. Create StorageClass `longhorn`
4. Configure 3 replicas for redundancy
5. Set as default storage class
6. Wait for all Longhorn pods to be ready

**Variables:**
- `longhorn_version` - Longhorn version (from defaults)
- `longhorn_replicas` - Number of replicas (default: 3)

**When to use:**
- After K3s deployment
- Before deploying applications that need persistent storage
- When expanding storage capacity

**Verify:**
```bash
kubectl get pods -n longhorn-system
kubectl get storageclass
```

---

### `deploy-registry.yml`

**Purpose:** Setup local Docker registry  
**Duration:** ~2 minutes  
**Requires:** Docker installed (done by setup-common)

```bash
ansible-playbook playbooks/deploy-registry.yml
```

**Tasks:**

**On Primary Master (node0):**
1. Start Docker service
2. Run registry container on port 5000
3. Persist images to `/var/lib/registry`
4. Enable restart always

**On All Nodes:**
1. Create `/etc/rancher/k3s/registries.yaml`
2. Configure insecure registry access
3. Restart K3s service
4. Verify registry accessible

**Variables:**
- `registry_address` - Registry hostname:port
- `registry_port` - Port number (default: 5000)

**When to use:**
- After K3s deployment
- Before building custom images
- When registry container stops

**Verify:**
```bash
curl -I http://node0.research.core:5000/v2/
# Expected: HTTP/1.1 200 OK
```

---

### `deploy-rancher.yml`

**Purpose:** Deploy Rancher web UI (optional)  
**Duration:** ~5-10 minutes  
**Requires:** K3s cluster with Longhorn

```bash
ansible-playbook playbooks/deploy-rancher.yml
```

**Tasks:**
1. Add Rancher Helm repository
2. Install cert-manager
3. Wait for cert-manager to be ready
4. Install Rancher via Helm
5. Configure NodePort access (30443)
6. Wait for Rancher pods to be ready
7. Display access instructions

**Variables:**
- `rancher_version` - Rancher version
- `rancher_hostname` - Hostname for Rancher

**When to use:**
- Optional: For web-based cluster management
- If you prefer UI over kubectl

**Access:**
```
https://node0:30443
```

---

## Application Deployment

### `build-docker-images.yml`

**Purpose:** Build OpenTAKServer images  
**Duration:** ~30 minutes (first), ~3-5 minutes (cached)  
**Requires:** Registry deployed

```bash
ansible-playbook playbooks/build-docker-images.yml --ask-become-pass
```

**Tasks:**
1. Configure Docker for insecure registry
2. Clone arclink repository to node0
3. Build OpenTAKServer image
4. Build UI image with nginx
5. Tag images with registry address
6. Push images to local registry
7. Verify images in registry

**Variables:**
- `registry_address` - Registry location
- `ots_version` - OpenTAKServer version
- `arclink_repo` - Git repository URL

**When to use:**
- Before deploying OpenTAKServer
- When updating to new version
- After code changes

---

### `build-ots-images.yml`

**Purpose:** Build images with Socket.IO patches  
**Duration:** ~30 minutes (first), ~3-5 minutes (cached)  
**Requires:** Registry deployed

```bash
ansible-playbook playbooks/build-ots-images.yml --ask-become-pass
```

**Tasks:**
Same as `build-docker-images.yml` but applies Socket.IO patches during build.

---

### `deploy-opentakserver.yml`

**Purpose:** Deploy OpenTAKServer without patches  
**Duration:** ~3-5 minutes  
**Requires:** Images built and pushed to registry

```bash
ansible-playbook playbooks/deploy-opentakserver.yml
```

**Tasks:**
1. Create namespace `tak`
2. Apply PostgreSQL deployment
3. Apply RabbitMQ deployment
4. Apply OpenTAKServer deployment
5. Wait for all pods to be ready
6. Display access information

**Variables:**
- `namespace` - Kubernetes namespace (default: tak)
- `ots_version` - Version tag for images

**When to use:**
- Deploying standard OpenTAKServer
- Testing without Socket.IO patches

---

### `deploy-opentakserver-with-patches.yml`

**Purpose:** Build and deploy OpenTAKServer with Socket.IO fixes  
**Duration:** ~30 minutes (first), ~3-5 minutes (cached)  
**Requires:** Registry deployed, sudo password

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Tasks:**

1. **Configure Docker:**
   - Add insecure registry to `/etc/docker/daemon.json`
   - Restart Docker daemon

2. **Clone Repository:**
   - Clone arclink to `/home/user/arclink`
   - Pull latest changes if exists

3. **Build OpenTAKServer with Patches:**
   - Auto-detect Python version (3.11, 3.12, 3.13)
   - Modify `extensions.py` with patches:
     ```python
     socketio = SocketIO(
         app,
         cors_allowed_origins='*',      # Enable CORS
         async_mode='gevent_uwsgi',
         # message_queue removed           # Remove RabbitMQ queue
         ping_timeout=60,                # Increase timeout
         ping_interval=25
     )
     ```
   - Build image
   - Push to registry

4. **Build UI Image:**
   - nginx configuration for WebSocket proxy
   - Build and push to registry

5. **Deploy to Kubernetes:**
   - Delete existing deployment (if any)
   - Apply manifests with custom images
   - Wait for pods to be ready

6. **Verify Patches:**
   - Check running container for patches
   - Confirm CORS enabled
   - Test WebSocket connectivity

**Variables:**
- `registry_address` - Registry hostname:port
- `ots_version` - OpenTAKServer version
- `namespace` - Kubernetes namespace

**When to use:**
- **Recommended:** For WebSocket functionality
- Initial deployment
- After code updates
- When patches need to be reapplied

**Verify:**
```bash
# Check pods
kubectl get pods -n tak

# Verify patches
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  python3 -c "import opentakserver.extensions; \
  print('✅ Patches verified!' if hasattr(opentakserver.extensions.socketio, 'cors_allowed_origins') else '❌ No patches')"
```

---

### `fix-ots-container.yml`

**Purpose:** Apply patches to running container  
**Duration:** ~1 minute  
**Requires:** OpenTAKServer pod running

```bash
ansible-playbook playbooks/fix-ots-container.yml
```

**Tasks:**
1. Find running OpenTAKServer pod
2. Auto-detect Python version in container
3. Apply Socket.IO patches to live container
4. Restart pod to apply changes

**Variables:**
- `namespace` - Kubernetes namespace

**When to use:**
- Quick fix without rebuilding images
- Testing patches before committing to image
- Emergency hotfix

**Note:** Changes are temporary and lost on pod restart. Use `deploy-opentakserver-with-patches.yml` for permanent fixes.

---

## Cluster Management

### `validate-k3s-cluster.yml`

**Purpose:** Verify cluster health  
**Duration:** ~30 seconds  
**Safe to run anytime**

```bash
ansible-playbook playbooks/validate-k3s-cluster.yml
```

**Checks:**
- K3s service running on all nodes
- All nodes in Ready state
- System pods running (coredns, metrics-server, etc.)
- Registry configuration exists
- Registry accessible from all nodes
- Longhorn healthy (if deployed)
- API server responsive

**When to use:**
- After deployment
- Troubleshooting issues
- Before making changes
- Regular health checks

---

### `restart-k3s.yml`

**Purpose:** Restart K3s service on all nodes  
**Duration:** ~2-3 minutes  
**Causes brief downtime**

```bash
ansible-playbook playbooks/restart-k3s.yml
```

**Tasks:**

**On Master Nodes:**
1. Restart k3s service
2. Wait for service to be active
3. Verify API server responding

**On Agent Nodes:**
1. Restart k3s-agent service
2. Wait for service to be active
3. Verify node reconnected

**When to use:**
- After registry configuration changes
- After network configuration changes
- When nodes show NotReady
- Troubleshooting connectivity issues

**Note:** Causes brief disruption to running workloads.

---

### `reset-cluster.yml`

**Purpose:** Complete cluster teardown  
**Duration:** ~2-3 minutes  
**Destructive operation - requires confirmation**

```bash
ansible-playbook playbooks/reset-cluster.yml
# Type 'yes' when prompted
```

**Tasks:**

**On All Nodes:**
1. Stop K3s/K3s-agent service
2. Run K3s uninstall script
3. Remove Docker containers (except registry)
4. Remove Docker images
5. Clean K3s directories
6. Remove configuration files

**Preserves:**
- SSH keys
- User accounts
- /etc/hosts entries
- Kernel module configuration
- System packages

**When to use:**
- Starting completely fresh
- Before major changes
- Troubleshooting deep issues
- Testing deployment from scratch

**After reset:**
```bash
# Redeploy from step 2 (skip bootstrap if SSH keys still work)
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

---

## Common Workflows

### Fresh Installation
```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

### Update OpenTAKServer
```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

### Reset and Redeploy
```bash
ansible-playbook playbooks/reset-cluster.yml  # Type 'yes'
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-longhorn.yml
ansible-playbook playbooks/deploy-registry.yml
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

### Add New Node
```bash
# Update inventory first
ansible-playbook playbooks/bootstrap.yml --limit=new_node --ask-pass
ansible-playbook playbooks/setup-common.yml --limit=new_node
ansible-playbook playbooks/deploy-k3s.yml --limit=new_node
```

### Health Check
```bash
ansible-playbook playbooks/validate-k3s-cluster.yml
```

## Variable Overrides

Most playbooks support variable overrides with `-e`:

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

# Verbose output
ansible-playbook playbooks/deploy-k3s.yml -v    # Basic
ansible-playbook playbooks/deploy-k3s.yml -vv   # More detail
ansible-playbook playbooks/deploy-k3s.yml -vvv  # Debug

# Dry run (check mode)
ansible-playbook playbooks/setup-common.yml --check

# Target specific nodes
ansible-playbook playbooks/restart-k3s.yml --limit=node0,node1
ansible-playbook playbooks/setup-common.yml --limit=k3s_master
```

## Next Steps

- **[Overview](./overview.md)** - Complete feature documentation
- **[Quick Start](./quick-start.md)** - Fast deployment guide
- **[Getting Started](./getting-started.md)** - Detailed walkthrough
- **[Progress Checklist](./progress-checklist.md)** - Implementation status
