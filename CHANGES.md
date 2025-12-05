# Deployment Changes Summary

## December 4, 2025 (Evening) - v0.2.1: Longhorn Storage Automation & Fixes

### Critical Storage Infrastructure Improvements

**Longhorn Deployment Automation**
- Complete automation of Longhorn distributed storage deployment
- Auto-detection and mounting of large NVMe partitions (1,513 GB total)
- Automatic disk configuration using `/mnt/longhorn` instead of default `/var/lib/longhorn`
- Master node taint removal to enable scheduling on all nodes
- Real-time monitoring of deployment progress with detailed status updates

**Critical Bug Fixes**
- **Fixed stuck replicasets**: Deployments showing 0/X replicas and not creating pods
  - Auto-detection of stuck deployment replicasets (UI, CSI components)
  - Automatic replicaset deletion and recreation to unstick deployments
- **Fixed missing CSI plugin daemonset**: CSI components crash-looping with "connection refused"
  - Detects when longhorn-csi-plugin daemonset fails to be created
  - Automatically restarts driver deployer to force CSI plugin creation
  - Recreates CSI deployment replicasets after CSI plugin is running
- **Fixed disk UUID mismatch**: After remounting partitions, Longhorn showed UUID errors
  - Resolved by deleting and recreating Longhorn node resources

**New Playbooks**
- `mount-longhorn-disks.yml` - Auto-detects and mounts large NVMe partitions
  - node0: 409 GB (/dev/nvme0n1p2)
  - nodes 1-6: 184 GB each (/dev/nvme0n1p3)
  - Formats as ext4, adds to /etc/fstab for persistence
- `wipe-longhorn-disks.yml` - Clean removal of Longhorn data and namespace
  - Safely stops processes, unmounts filesystems
  - Removes all data from /mnt/longhorn
  - Forces namespace deletion with finalizer removal if stuck
- `prepare-cluster-disks.yml` - For fresh installations, prepares disk structure

**Enhanced Playbooks**
- `deploy-longhorn.yml` - Major enhancements:
  - KUBECONFIG environment variable configuration
  - Master node taint removal (CriticalAddonsOnly=true:NoExecute)
  - Node annotation to disable default disk
  - Manifest modification to use /mnt/longhorn hostPath
  - /mnt/longhorn disk configuration on all nodes with allowScheduling
  - **Auto-fix for stuck deployment replicasets**
  - **Auto-fix for missing CSI plugin daemonset**
  - Real-time progress monitoring with pod counts and status
  - Deployment readiness verification
  - Longhorn UI exposure via NodePort (30630)

**Monitoring Tools**
- `scripts/helpers/monitor-longhorn.sh` - Real-time dashboard with auto-refresh
  - Shows deployment status, pod counts, node storage capacity
  - Auto-detects KUBECONFIG location
- `scripts/helpers/stream-longhorn-logs.sh` - Live log streaming
  - Supports manager, ui, driver, or all components

**Documentation Updates**
- Updated `docs/docs/guides/quickstart.md` - Correct deployment order
- Updated `docs/docs/guides/complete-deployment.md` - Detailed Longhorn steps
- Updated `docs/docs/guides/ansible/quick-start.md` - Mount disks step, Longhorn details
- Added deployment order callouts emphasizing Longhorn before apps
- Added Longhorn troubleshooting sections
- Added storage capacity verification to success indicators

**Documentation Files**
- `ansible/LONGHORN-WIPE-REDEPLOY.md` - Complete Longhorn management guide
- `ansible/DISK-PREPARATION.md` - Disk setup and partitioning guide

**Testing**
- ✅ Complete wipe → mount → deploy workflow tested end-to-end
- ✅ All 7 nodes showing correct storage (1,513 GB total)
- ✅ All Longhorn components healthy (6 deployments, 3 daemonsets)
- ✅ Longhorn UI accessible at http://10.0.0.160:30630
- ✅ Auto-fix for stuck replicasets verified
- ✅ Auto-fix for missing CSI plugin verified
- ✅ Storage persistent across node reboots via /etc/fstab

**Deployment Order Clarified**
1. K3s cluster
2. Rancher (optional) - Management UI
3. **Mount Longhorn disks (first time only)**
4. **Longhorn Storage (required)** - Must be before apps
5. Docker Registry
6. OpenTAK Server

---

## December 4, 2025 - v0.2.0: Complete Ansible Automation

### Major Release: Full Lifecycle Automation

**Ansible Implementation**
- 15 playbooks for complete lifecycle management
- 5 reusable roles: common, k3s-master, k3s-agent, docker-registry, docker-build
- High Availability support with 3+ master nodes and embedded etcd
- Automated SSH key distribution and system preparation
- Complete cluster management: deploy, reset, restart, validate
- Tested on 7-node Raspberry Pi 5 cluster (3 masters + 4 agents)

**Socket.IO Fixes**
- Auto-detection of Python version (3.11, 3.12, 3.13)
- CORS headers enabled: `cors_allowed_origins='*'`
- RabbitMQ message_queue removed
- Ping timeout increased to 60 seconds
- Patches applied automatically during image build
- Verification in running containers
- WebSocket connections working (HTTP 200 instead of 400 errors)

**Build Optimization**
- Docker layer caching for fast rebuilds
- First build: ~30 minutes
- Subsequent builds: ~3-5 minutes with cache
- Automated push to local registry
- Multi-node image distribution

**Documentation Overhaul**
- Comprehensive Quick Start guide (Ansible + manual approaches)
- Complete Deployment guide with step-by-step instructions
- Ansible overview and automation details
- Complete playbooks reference (all 15 playbooks)
- Getting Started guide for new deployments
- Progress checklist (all phases complete)
- High Availability configuration guide
- Troubleshooting guides for each deployment step

**Infrastructure Automation**
- System preparation (kernel modules, sysctl, packages)
- K3s cluster deployment with HA
- Longhorn distributed storage
- Local Docker registry setup
- Rancher UI deployment (optional)
- Pre-flight and post-deployment validation

---

## December 3, 2025 - Multi-Node Deployment & Automation

### 1. **Fixed Redeploy Script for Multi-Node Clusters**
**Problem**: Redeploy script was incomplete - skipped image building and registry configuration  
**Root Cause**:
- Script only called `deploy.sh`, missing configuration and build steps
- No registry configuration distribution to agent nodes
- Images weren't being built before deployment, causing ImagePullBackOff errors

**Solution**:
- Redeploy script now runs complete workflow: configure → build → distribute → deploy
- Automatically detects and configures all agent nodes
- Added registry configuration distribution via SSH
- Restarts K3s services on all nodes to apply changes
- Skips reconfiguration if `config.env` already exists

**New Features**:
- `scripts/helpers/setup-ssh-keys.sh` - Automates SSH key distribution
- Automatic multi-node detection and configuration
- Passwordless sudo setup for automation
- Registry verification before deployment

### 2. **Fixed Multi-Node Registry Issues**
**Problem**: Pods failing with ImagePullBackOff on agent nodes  
**Root Cause**: Agent nodes missing `/etc/rancher/k3s/registries.yaml` configuration

**Solution**:
- Redeploy script now distributes registry config to all nodes
- Added SSH-based automation for agent configuration
- Handles both `k3s-agent` and `k3s` service names
- Verifies registry is ready before proceeding

### 3. **Build Script Path Fixes**
**Problem**: Build scripts failed when run from different directories
- `docker/build.sh` expected to run from root, failed in docker directory
- `docker/setup.sh` had hardcoded paths that broke

**Solution**:
- Scripts now detect their current directory and adjust paths dynamically
- Can be run from either root or docker directory
- Fixed UI version default from `main` to `master` (correct branch name)

### 4. **Improved Configuration Script**
**Enhancements**:
- Detects multi-node clusters automatically
- Offers automatic agent node configuration
- Prevents duplicate registry entries in `registries.yaml`
- Better error handling and user feedback
- Cleaner YAML generation with proper formatting

### 5. **Comprehensive Documentation**
**New Guides**:
- `docs/docs/guides/troubleshooting.md` - Complete troubleshooting guide covering:
  - ImagePullBackOff errors and solutions
  - SSH and passwordless sudo setup
  - Registry configuration verification
  - Common issues and debugging commands
- `docs/docs/guides/ansible-deployment.md` - Planning doc for Ansible automation
- Updated `docs/docs/guides/setup.md` - Added SSH key prerequisites for multi-node

**Updated Documentation**:
- README.md - Added troubleshooting section and setup-ssh-keys.sh command
- Troubleshooting guide with step-by-step fixes
- Clear explanation of multi-node requirements

### Files Modified
- `scripts/redeploy.sh` - Complete rewrite with multi-node support
- `scripts/configure.sh` - Multi-node detection and automation
- `scripts/helpers/setup-ssh-keys.sh` - New utility for SSH automation
- `docker/build.sh` - Path detection and fixes
- `docker/setup.sh` - Fixed manifest path detection
- `README.md` - Added troubleshooting and SSH key management
- `docs/docs/guides/troubleshooting.md` - New comprehensive guide
- `docs/docs/guides/ansible-deployment.md` - Planning document
- `docs/docs/guides/setup.md` - SSH key prerequisites

### Testing
- ✅ Multi-node cluster deployment (7 nodes)
- ✅ SSH key automation
- ✅ Registry configuration distribution
- ✅ Image building and pushing
- ✅ Complete redeploy workflow
- ✅ Pod startup and image pulling

### Next Steps
- Consider Ansible implementation for better automation
- Evaluate HA deployment with multi-replica pods
- Implement automated testing for deployment scripts

---

## What We Fixed Previously

### 1. **Socket.IO Performance Issues**
**Problem**: Pages taking 25+ seconds to load with constant 400 errors  
**Root Cause**: 
- Missing CORS configuration in Socket.IO initialization
- RabbitMQ message queue breaking Flask-Security session context

**Solution**:
- Added `cors_allowed_origins='*'` to Socket.IO initialization
- Removed RabbitMQ message_queue parameter (runs in-process now)
- Increased ping_timeout from 1s to 60s

**Security Impact**: ✅ **None** - Flask-Security authentication still active, CORS is standard for proxied apps

### 2. **Made Deployment Portable**
**Problem**: Hardcoded IPs (10.0.0.160) made deployment non-portable  
**Solution**:
- Created `config.env.example` with all configurable values
- Created `scripts/configure.sh` for interactive setup
- Created comprehensive `INSTALL.md` guide
- Updated README with quick start

**Files Created**:
- `config.env.example` - Template configuration
- `INSTALL.md` - Complete installation guide
- `scripts/configure.sh` - Interactive configuration wizard

### 3. **Docker Image Optimizations**
**Changes Made**:
- Pre-install all dependencies in image (gcc, libpq5, ffmpeg)
- Apply Socket.IO patches at build time
- Remove build tools after installation to reduce image size

**Result**: 10-second pod startup vs 10-15 minutes previously

## Current Architecture

### Components
```
┌─────────────────────────────────────┐
│         K3s Cluster                 │
│  ┌──────────────────────────────┐   │
│  │  OpenTAKServer Pod           │   │
│  │  ┌────────┐  ┌────────────┐  │   │
│  │  │ Nginx  │→ │    OTS     │  │   │
│  │  │ (UI)   │  │ (Flask)    │  │   │
│  │  └────────┘  └────────────┘  │   │
│  └──────────────────────────────┘   │
│  ┌──────────┐  ┌──────────┐         │
│  │PostgreSQL│  │ RabbitMQ │         │
│  └──────────┘  └──────────┘         │
└─────────────────────────────────────┘
```

### Network Flow
1. **Browser** → `http://<node-ip>:31080`
2. **NodePort** → **Nginx** (port 8080)
3. **Nginx** → **OTS Flask** (port 8081) 
4. **Flask** → **PostgreSQL** (port 5432)
5. **Flask** → **RabbitMQ** (port 5672, for async tasks only)

### Socket.IO Flow (Fixed)
- Socket.IO runs **in-process** with Flask (no message queue)
- CORS enabled for proxy access
- Flask-Security sessions maintained properly
- **Result**: Fast real-time updates, no 400 errors

## Configuration Variables

All configurable in `config.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| PRIMARY_NODE_IP | 10.0.0.160 | Main node IP address |
| REGISTRY_ADDRESS | 10.0.0.160:5000 | Docker registry location |
| WEB_NODEPORT | 31080 | Web UI access port |
| TCP_COT_NODEPORT | 31088 | TAK TCP data port |
| SSL_COT_NODEPORT | 31089 | TAK SSL data port |
| NAMESPACE | tak | Kubernetes namespace |
| OTS_VERSION | 1.6.3 | OpenTAKServer version |
| POSTGRES_PASSWORD | otspassword | Database password |
| RABBITMQ_PASSWORD | guest | RabbitMQ password |

## Security Status

### ✅ Still Protected
- Flask-Security authentication active
- Session cookies required for API access
- CSRF protection enabled
- Password hashing with argon2
- Static secrets prevent hash invalidation

### ⚠️ Production Recommendations
1. **Change default passwords** - Update database & RabbitMQ credentials
2. **Generate new secrets** - Use `scripts/configure.sh` to create random SECRET_KEY
3. **Restrict CORS** - Change `cors_allowed_origins='*'` to specific domain if desired
4. **Use TLS** - Add ingress with proper certificates
5. **Firewall NodePorts** - Restrict external access as needed

## Deployment Steps for New Users

```bash
# 1. Clone repository
git clone <repo-url>
cd opentakserver-k3s

# 2. Configure for your environment
./scripts/configure.sh
# This creates config.env with your settings

# 3. Follow installation guide
# See INSTALL.md for detailed steps

# 4. Quick deploy (after configuration)
source config.env
# Set up registry (see INSTALL.md)
# Build images (see INSTALL.md)
./scripts/deploy.sh

# 5. Set admin password
./scripts/set-admin-password.sh
```

## Testing the Deployment

### Check Services
```bash
source config.env
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
```

### Access Web UI
```bash
source config.env
echo "http://${PRIMARY_NODE_IP}:${WEB_NODEPORT}"
```

### View Logs
```bash
source config.env
kubectl logs -n ${NAMESPACE} -l app=opentakserver -c ots --tail=50
```

### Test Socket.IO
Open browser developer tools and watch Network tab - should see:
- ✅ `socket.io` requests returning 200 OK
- ✅ Pages loading in < 2 seconds
- ❌ No more 400 errors on POST requests

## Files Modified

### Docker Images
- `docker/opentakserver/Dockerfile` - Added Socket.IO patches, CORS config
- `docker/ui/Dockerfile` - No changes (uses upstream)

### Kubernetes Manifests
- `manifests/ots-with-ui-custom-images.yaml` - Uses custom images, static secrets
- `manifests/nginx-config.yaml` - Cookie forwarding for sessions

### Documentation
- `README.md` - Updated with quick start
- `INSTALL.md` - **NEW** - Complete installation guide
- `config.env.example` - **NEW** - Configuration template
- `CHANGES.md` - **NEW** - This document

### Scripts
- `scripts/configure.sh` - **NEW** - Interactive configuration wizard
- `scripts/set-admin-password.sh` - Updated to use config.env

## Performance Metrics

### Before Optimization
- Pod startup: 10-15 minutes (init container build)
- Page load: 25+ seconds (Socket.IO retries)
- Socket.IO: Constant 400 errors
- Login: Slow password hashing

### After Optimization
- Pod startup: **10 seconds** (pre-built image)
- Page load: **< 2 seconds** (working Socket.IO)
- Socket.IO: **200 OK responses**
- Login: Fast (authentication working properly)

## Known Limitations

1. **RabbitMQ still deployed** - Currently only used for async tasks, not Socket.IO
2. **CORS set to wildcard** - Can be restricted if needed
3. **NodePort access** - Consider LoadBalancer or Ingress for production
4. **No TLS by default** - Add ingress controller with certificates for HTTPS

## Future Improvements

- [ ] Helm chart for easier deployment
- [ ] Automated backup scripts
- [ ] Health monitoring dashboard
- [ ] TLS/Let's Encrypt automation
- [ ] Multi-region deployment guide
- [ ] HA PostgreSQL with replication
