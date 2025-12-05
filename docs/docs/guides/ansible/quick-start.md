---
sidebar_position: 1
---

# Quick Start Guide

Deploy OpenTAKServer on K3s in minutes with complete automation.

## Overview

This guide gets you from configured inventory to running application as fast as possible.

**Prerequisites:**
- Ansible installed on control node
- SSH access to cluster nodes
- Inventory configured

**Time:** ~15 minutes (with cached Docker images) or ~45 minutes (first build)

## One-Command Deployment

If you've already run the bootstrap once:

```bash
cd ~/arclink/ansible

# Deploy entire stack
ansible-playbook playbooks/deploy-k3s.yml && \
ansible-playbook playbooks/deploy-rancher.yml && \
ansible-playbook playbooks/deploy-longhorn.yml && \
ansible-playbook playbooks/deploy-registry.yml && \
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

:::info Deployment Order
Deploy in this order:
1. K3s cluster → 2. Rancher (optional) → 3. **Longhorn (required)** → 4. Registry → 5. Apps

Longhorn provides persistent storage required by applications.
:::

## Step-by-Step Deployment

### 1. Bootstrap SSH Access (First Time Only)

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

**Enter your SSH password when prompted.** This sets up passwordless authentication for all future commands.

**Duration:** ~1 minute

---

### 2. Prepare Systems

```bash
ansible-playbook playbooks/setup-common.yml
```

**What it does:**
- Installs required packages
- Loads kernel modules
- Configures sysctl parameters
- Updates system

**Duration:** ~3-5 minutes

---

### 3. Deploy K3s Cluster

```bash
ansible-playbook playbooks/deploy-k3s.yml
```

**What it does:**
- Installs K3s on master nodes with HA
- Joins agent nodes to cluster
- Configures kubectl

**Duration:** ~5-10 minutes

---

### 4. Deploy Rancher (Optional)

```bash
ansible-playbook playbooks/deploy-rancher.yml
```

**What it does:**
- Installs cert-manager
- Deploys Rancher management UI
- Provides web-based cluster administration

**Duration:** ~5-10 minutes

**Access:** `https://rancher.yourdomain.com`

:::tip Why Rancher?
Provides invaluable visibility: pod logs, resource usage, deployment status, and troubleshooting tools.
:::

---

### 5. Mount Longhorn Storage (First Time Only)

```bash
ansible-playbook playbooks/mount-longhorn-disks.yml
```

**What it does:**
- Auto-detects large unmounted NVMe partitions
- Formats as ext4 with "longhorn" label
- Mounts to `/mnt/longhorn` on all nodes
- Adds to `/etc/fstab` for persistence

**Duration:** ~1-2 minutes

**Storage detected:**
- node0: ~409 GB
- nodes 1-6: ~184 GB each
- **Total: ~1,513 GB**

:::info First Time Only
Run this playbook once during initial setup. The mounts persist across reboots via `/etc/fstab`.
:::

---

### 6. Deploy Longhorn Storage (Required)

```bash
ansible-playbook playbooks/deploy-longhorn.yml
```

**What it does:**
- Removes master node taints (enables scheduling on all nodes)
- Deploys Longhorn distributed storage
- Configures `/mnt/longhorn` on all nodes (disables default disk)
- Creates `longhorn` storage class (set as default)
- Configures 3 replicas for high availability
- Auto-fixes stuck replicasets and CSI components
- Exposes UI via NodePort

**Duration:** ~3-5 minutes

**Access Longhorn UI:** `http://node0:30630` (or any node IP)

:::warning Deploy Before Applications
Longhorn must be deployed **before registry and OpenTAK Server** as they require persistent storage volumes.
:::

---

### 7. Deploy Docker Registry

```bash
ansible-playbook playbooks/deploy-registry.yml
```

**What it does:**
- Starts local registry on node0
- Configures all nodes to trust it
- Uses Docker volumes for persistence

**Duration:** ~2 minutes

---

### 8. Deploy OpenTAKServer

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Enter sudo password when prompted.**

**What it does:**
- Builds OpenTAKServer with Socket.IO patches
- Builds UI with nginx
- Pushes to registry
- Deploys to K3s
- Verifies patches applied

**Duration:** 
- First run: ~30 minutes (building images)
- Subsequent: ~3-5 minutes (Docker cache)

---

### 9. Verify Deployment

```bash
ansible-playbook playbooks/validate-k3s-cluster.yml
```

Or check manually:

```bash
# SSH to node0
ssh node0

# Check pods
kubectl get pods -n tak

# Should see:
# NAME                             READY   STATUS    RESTARTS   AGE
# opentakserver-xxxxxxxxxx-xxxxx   2/2     Running   0          2m
# postgres-xxxxxxxxxx-xxxxx        1/1     Running   0          2m
# rabbitmq-xxxxxxxxxx-xxxxx        1/1     Running   0          2m
```

## Access the Application

### Web UI
```
http://node0.research.core:31080
```
Or use your node's IP:
```
http://10.0.0.160:31080
```

### Default Credentials
- **Username:** `administrator`
- **Password:** `password`

:::caution Change Password
Change the default password immediately after first login!
:::

## Verification Commands

### Check All Pods
```bash
kubectl get pods -n tak
```

### Check Services
```bash
kubectl get svc -n tak
```

### Verify Socket.IO Patches
```bash
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  python3 -c "import opentakserver.extensions; print('✅ Patches verified!' if hasattr(opentakserver.extensions.socketio, 'cors_allowed_origins') else '❌ No patches')"
```

### Check WebSocket Logs
```bash
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n tak ${POD} -c nginx --tail=50 | grep socket.io
```

**Expected:** HTTP 200 responses, not 400 errors

## Update OpenTAKServer

To rebuild and redeploy only OpenTAKServer:

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Duration:** ~3-5 minutes (with Docker cache)

## Reset Everything

To start completely fresh:

```bash
ansible-playbook playbooks/reset-cluster.yml
# Type 'yes' when prompted

# Then redeploy from step 2
ansible-playbook playbooks/setup-common.yml
# ... continue with remaining steps
```

## Common Issues

### SSH Connection Failed
```bash
# Test connectivity
ansible -i inventory/production.yml all -m ping

# Check SSH config
ssh -v node0
```

### Pods Not Starting
```bash
# Check pod status
kubectl describe pod -n tak <pod-name>

# Check events
kubectl get events -n tak --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n tak <pod-name>
```

### Registry Pull Failed
```bash
# Verify registry is running
ssh node0
docker ps | grep registry

# Check if nodes can reach registry
ansible -i inventory/production.yml all -m shell -a "curl -I http://node0.research.core:5000/v2/"
```

### Docker Build Fails
```bash
# Clear Docker cache and rebuild
ssh node0
docker system prune -af
cd ~/arclink
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

### Longhorn Not Showing Full Storage
```bash
# Check if partitions are mounted
ansible -i inventory/production.yml all -m shell -a "df -h /mnt/longhorn"

# Remount if needed
ansible-playbook playbooks/mount-longhorn-disks.yml

# Verify in Longhorn UI
http://node0:30630
```

### Longhorn Pods CrashLooping
```bash
# Check CSI plugin daemonset
export KUBECONFIG=/path/to/kubeconfig
kubectl get daemonset longhorn-csi-plugin -n longhorn-system

# If missing, redeploy Longhorn (has auto-fix)
ansible-playbook playbooks/deploy-longhorn.yml
```

## Next Steps

- **[Overview](./overview.md)** - Complete feature documentation
- **[High Availability](./high-availability.md)** - HA configuration details
- **[Progress Checklist](./progress-checklist.md)** - Implementation status

## Configuration Reference

### Default Values

```yaml
# In ansible/roles/docker-build/defaults/main.yml
registry_address: "node0.research.core:5000"
ots_version: "1.6.3"
namespace: "tak"
```

### Override Variables

```bash
# Different version
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml \
  -e "ots_version=1.6.4" \
  --ask-become-pass

# Different registry
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml \
  -e "registry_address=registry.example.com:5000" \
  --ask-become-pass
```

## Success Indicators

✅ All pods in `Running` state with `READY 2/2` or `1/1`  
✅ Longhorn showing ~1,513 GB total storage across 7 nodes  
✅ Longhorn UI accessible at http://node0:30630  
✅ Web UI accessible at http://node0:31080  
✅ Socket.IO patches verified in container  
✅ WebSocket connections showing HTTP 200 in logs  
✅ Can login with default credentials  

Your OpenTAKServer deployment is ready! 🎉
