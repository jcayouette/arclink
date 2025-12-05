# Longhorn Disk Wipe and Redeployment Guide

## Overview
This guide walks through wiping existing Longhorn disks on nodes 0-6 and redeploying Longhorn with custom disk configuration at `/mnt/longhorn`.

## Prerequisites
- K3s cluster running on 7 nodes (node0-6)
- Ansible installed on WSL2 Ubuntu 24.04
- SSH access configured to all nodes as user `acmeastro`
- kubectl configured to access your cluster

## Step 1: Verify SSH Access
First, ensure you can SSH to all nodes:

```bash
cd /home/linux/arclink/ansible
ansible -i inventory/production.yml k3s_cluster -m ping
```

Expected output: All nodes should return `pong`

## Step 2: Backup Important Data (Optional but Recommended)
If you have any important data in Longhorn volumes, back it up first:

```bash
# List all PVCs
kubectl get pvc --all-namespaces

# For each important PVC, consider creating a backup
# (Longhorn UI -> Volume -> Create Backup)
```

## Step 3: Wipe Longhorn Disks
Run the wipe playbook to clean all Longhorn data:

```bash
cd /home/linux/arclink/ansible
ansible-playbook -i inventory/production.yml playbooks/wipe-longhorn-disks.yml
```

This playbook will:
1. Stop processes using `/mnt/longhorn`
2. Unmount any filesystems under `/mnt/longhorn`
3. Remove all data from `/mnt/longhorn` on nodes 0-6
4. Recreate clean `/mnt/longhorn` directories
5. Delete Longhorn namespace from Kubernetes
6. Remove Longhorn CRDs

Expected duration: 2-5 minutes

## Step 4: Verify Cleanup
Check that Longhorn is completely removed:

```bash
# Should return "not found"
kubectl get namespace longhorn-system

# Should return empty or no longhorn-related items
kubectl get crd | grep longhorn

# Verify disk cleanup on a node
ssh acmeastro@node0 "ls -la /mnt/longhorn"
# Should show empty directory
```

## Step 5: Redeploy Longhorn with Custom Disk Configuration

### Option A: Deploy with Built-in Monitoring (Recommended)
The playbook now includes real-time progress monitoring:

```bash
cd /home/linux/arclink/ansible
ansible-playbook -i inventory/production.yml playbooks/deploy-longhorn.yml
```

You'll see:
- ✓ Real-time pod startup progress
- ✓ Node registration status
- ✓ Disk configuration progress per node
- ✓ Visual indicators for each step

### Option B: Deploy with Live Dashboard Monitoring
In a separate terminal, run the monitoring dashboard:

```bash
# Terminal 1: Start monitoring dashboard
/home/linux/arclink/scripts/helpers/monitor-longhorn.sh

# Terminal 2: Run deployment
cd /home/linux/arclink/ansible
ansible-playbook -i inventory/production.yml playbooks/deploy-longhorn.yml
```

The dashboard shows:
- Pod status with color coding (running/pending/failed)
- Longhorn node registration
- Volume status
- Recent events
- Refreshes every 3 seconds

### Option C: Stream Live Logs
Watch Longhorn manager logs in real-time:

```bash
# Terminal 1: Stream logs
/home/linux/arclink/scripts/helpers/stream-longhorn-logs.sh manager

# Terminal 2: Run deployment
cd /home/linux/arclink/ansible
ansible-playbook -i inventory/production.yml playbooks/deploy-longhorn.yml
```

Available log streams:
- `manager` - Manager pod logs (default)
- `ui` - UI pod logs
- `driver` - Driver deployer logs
- `instance-manager` - Instance manager logs
- `all` - All component logs

### What the Playbook Does:
1. Create the `longhorn-system` namespace
2. Disable default disk creation
3. Install Longhorn v1.7.2
4. Wait for Longhorn manager pods to be ready
5. Configure `/mnt/longhorn` disk on each node (nodes 0-6)
6. Set Longhorn as the default StorageClass
7. Expose Longhorn UI via NodePort

Expected duration: 5-10 minutes

## Step 6: Verify Deployment

### Check Longhorn Pods
```bash
kubectl get pods -n longhorn-system
```
All pods should be in `Running` state.

### Check Longhorn Nodes and Disks
```bash
kubectl get nodes.longhorn.io -n longhorn-system
```
Should show all 7 nodes.

```bash
kubectl get nodes.longhorn.io -n longhorn-system -o yaml | grep -A5 "disks:"
```
Each node should have `mnt-longhorn` disk configured at `/mnt/longhorn`.

### Check StorageClass
```bash
kubectl get storageclass
```
`longhorn` should be marked as default (has `(default)` annotation).

### Access Longhorn UI
Get the NodePort:
```bash
kubectl get svc longhorn-frontend-nodeport -n longhorn-system
```

Access the UI at: `http://10.0.0.160:<NodePort>` (replace with actual NodePort)

In the Longhorn UI:
- Navigate to **Node** → Verify all 7 nodes are listed
- Check that each node shows the `/mnt/longhorn` disk
- Verify disk space is available and scheduling is enabled

## Step 7: Test Block Volume Creation

Create a test PVC:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF
```

Verify PVC is bound:
```bash
kubectl get pvc longhorn-test-pvc
```
Status should be `Bound`.

Create a test pod to use the volume:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: longhorn-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: longhorn-test-pvc
EOF
```

Verify pod is running and can write to the volume:
```bash
kubectl exec longhorn-test-pod -- sh -c "echo 'test' > /data/test.txt && cat /data/test.txt"
```
Should output: `test`

Clean up test resources:
```bash
kubectl delete pod longhorn-test-pod
kubectl delete pvc longhorn-test-pvc
```

## Monitoring Tools

### Real-time Dashboard
```bash
/home/linux/arclink/scripts/helpers/monitor-longhorn.sh
```
Shows comprehensive status with auto-refresh.

### Stream Specific Component Logs
```bash
# Manager logs (most important)
/home/linux/arclink/scripts/helpers/stream-longhorn-logs.sh manager

# UI logs
/home/linux/arclink/scripts/helpers/stream-longhorn-logs.sh ui

# All logs
/home/linux/arclink/scripts/helpers/stream-longhorn-logs.sh all
```

### Manual Monitoring Commands
```bash
# Watch pod status
watch -n 2 'kubectl get pods -n longhorn-system'

# Watch node registration
watch -n 2 'kubectl get nodes.longhorn.io -n longhorn-system'

# Follow manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager -f --tail=50

# View recent events
kubectl get events -n longhorn-system --sort-by='.lastTimestamp' | tail -20
```

## Troubleshooting

### Pods Stuck in Terminating
If the wipe playbook times out waiting for namespace deletion:
```bash
kubectl get namespace longhorn-system -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/longhorn-system/finalize -f -
```

### Node Not Showing Disk
Check node status:
```bash
kubectl describe nodes.longhorn.io/<node-name> -n longhorn-system
```

Manually patch node if needed:
```bash
kubectl patch nodes.longhorn.io/<node-name> -n longhorn-system --type=merge -p '
spec:
  disks:
    mnt-longhorn:
      allowScheduling: true
      evictionRequested: false
      path: /mnt/longhorn
      storageReserved: 0
      tags: []
'
```

### Disk Not Schedulable
Check disk status in Longhorn UI or via kubectl:
```bash
kubectl get nodes.longhorn.io -n longhorn-system -o json | jq '.items[].status.diskStatus'
```

Enable scheduling:
```bash
kubectl patch nodes.longhorn.io/<node-name> -n longhorn-system --type=merge -p '{"spec":{"disks":{"mnt-longhorn":{"allowScheduling":true}}}}'
```

### Check Logs
View Longhorn manager logs:
```bash
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
```

## Configuration Details

### Disk Configuration
- **Path**: `/mnt/longhorn`
- **Default Disk**: Disabled (won't use `/var/lib/longhorn`)
- **Nodes**: All 7 nodes (node0-6)
- **Storage Reserved**: 0 (uses all available space)
- **Scheduling**: Enabled on all disks

### Storage Classes
- **longhorn**: Default, RWO (ReadWriteOnce) block volumes
- **longhorn-static**: For pre-provisioned volumes

### Volume Features
- **Replication**: 3 replicas by default (can be changed per volume)
- **Snapshots**: Supported
- **Backups**: Supported (requires backup target configuration)
- **Volume Cloning**: Supported
- **Volume Expansion**: Supported

## Next Steps

1. **Configure Backups** (Optional): Set up S3/NFS backup target in Longhorn UI
2. **Adjust Replica Count**: Default is 3, adjust if needed for your cluster size
3. **Set Node Tags**: Use tags to control volume placement if needed
4. **Monitor Storage**: Regularly check disk usage in Longhorn UI

## References

- Longhorn Documentation: https://longhorn.io/docs/
- Storage Configuration: https://longhorn.io/docs/1.7.2/nodes-and-volumes/nodes/
- Troubleshooting: https://longhorn.io/docs/1.7.2/troubleshooting/
