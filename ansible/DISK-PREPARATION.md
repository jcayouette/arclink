# K3s Cluster Disk Preparation Guide

## Overview
This guide ensures consistent disk partitioning across all cluster nodes for production deployments.

## Standard Disk Layout

Each node will have the following partition scheme on the primary NVMe drive:

| Partition | Size | Mount Point | Purpose |
|-----------|------|-------------|---------|
| nvme0n1p1 | 512MB | /boot/firmware | Boot partition (FAT32) |
| nvme0n1p2 | 50GB | / | Root filesystem (ext4) |
| nvme0n1p3 | Remaining | /mnt/longhorn | Longhorn storage (ext4) |

## For New Cluster Deployments

### Step 1: Prepare Fresh Nodes
Use this playbook **ONLY** on fresh installations before OS installation:

```bash
cd /home/linux/arclink/ansible
ansible-playbook -i inventory/production.yml playbooks/prepare-cluster-disks.yml
```

**WARNING**: This will repartition disks and destroy existing data!

### Step 2: Install Operating System
Install your OS (Ubuntu/Debian) to the root partition (nvme0n1p2).

### Step 3: Deploy K3s
```bash
ansible-playbook -i inventory/production.yml playbooks/deploy-k3s.yml
```

### Step 4: Deploy Longhorn
```bash
ansible-playbook -i inventory/production.yml playbooks/deploy-longhorn.yml
```

Longhorn will automatically use `/mnt/longhorn` (nvme0n1p3).

## For Existing Clusters (Current Situation)

If you already have a running cluster with OS installed but Longhorn partition not mounted:

### Step 1: Mount Existing Partitions
```bash
cd /home/linux/arclink/ansible
ansible-playbook -i inventory/production.yml playbooks/mount-longhorn-disks.yml
```

This will:
- Detect the largest unmounted partition on each node
- Format it with ext4 if needed
- Mount it to `/mnt/longhorn`
- Add to `/etc/fstab` for persistence
- Restart Longhorn to detect new space

### Step 2: Verify Longhorn Storage
```bash
export KUBECONFIG=/home/linux/arclink/ansible/kubeconfig
kubectl get nodes.longhorn.io -n longhorn-system
```

Check the Longhorn UI at `http://node0:30630` to verify storage capacity.

## Expected Storage Capacity

Based on your hardware:

| Node | Total Disk | Root (/) | Longhorn (/mnt/longhorn) |
|------|------------|----------|--------------------------|
| node0 | 500GB | 50GB | ~450GB |
| node1 | 250GB | 50GB | ~200GB |
| node2 | 250GB | 50GB | ~200GB |
| node3 | 250GB | 50GB | ~200GB |
| node4 | 250GB | 50GB | ~200GB |
| node5 | 250GB | 50GB | ~200GB |
| node6 | 250GB | 50GB | ~200GB |

**Total Longhorn Capacity**: ~1.65TB raw (with 3x replication = ~550GB usable)

## Automation for Customer Deployments

### Option 1: Image-Based Deployment
1. Prepare one node with correct partitioning using `prepare-cluster-disks.yml`
2. Install and configure OS
3. Create disk image (using Clonezilla, dd, or similar)
4. Deploy image to all nodes
5. Adjust hostname/IP per node
6. Run K3s and Longhorn playbooks

### Option 2: Ansible-Based Deployment
Include disk preparation in your bootstrap playbook:

```yaml
- import_playbook: prepare-cluster-disks.yml
- import_playbook: setup-common.yml
- import_playbook: deploy-k3s.yml
- import_playbook: deploy-longhorn.yml
```

### Option 3: Cloud-Init / Pre-seed
For automated installations, include partitioning commands in cloud-init or preseed configuration:

```yaml
# Example cloud-init storage config
storage:
  layout:
    name: custom
  config:
    - type: disk
      id: disk0
      path: /dev/nvme0n1
      ptable: gpt
      wipe: superblock
    - type: partition
      id: boot_partition
      device: disk0
      size: 512M
      flag: boot
    - type: partition
      id: root_partition
      device: disk0
      size: 50G
    - type: partition
      id: longhorn_partition
      device: disk0
      size: -1  # Use remaining space
```

## Validation

After deployment, verify on each node:

```bash
# Check partition layout
lsblk /dev/nvme0n1

# Check mount points
df -h / /mnt/longhorn

# Verify fstab entry
grep longhorn /etc/fstab

# Check Longhorn sees the storage
export KUBECONFIG=/path/to/kubeconfig
kubectl get nodes.longhorn.io -n longhorn-system -o wide
```

## Troubleshooting

### Longhorn not showing full capacity
1. Check if partition is mounted: `df -h /mnt/longhorn`
2. Restart Longhorn manager: `kubectl rollout restart ds/longhorn-manager -n longhorn-system`
3. Check Longhorn logs: `kubectl logs -n longhorn-system -l app=longhorn-manager`

### Partition not mounting at boot
1. Verify fstab entry: `cat /etc/fstab | grep longhorn`
2. Test mount: `mount -a`
3. Check systemd: `systemctl status mnt-longhorn.mount`

### Need to repartition existing cluster
**WARNING**: This will destroy data!

1. Backup all data from Longhorn volumes
2. Delete all PVCs and Longhorn resources
3. Unmount /mnt/longhorn on all nodes
4. Run `prepare-cluster-disks.yml`
5. Redeploy Longhorn

## Best Practices

1. **Always use the same partition scheme** across all nodes
2. **Mount Longhorn partition with `noatime`** to reduce disk writes
3. **Use labels** for partitions (easier to reference in fstab)
4. **Monitor disk usage** - set alerts at 80% capacity
5. **Plan for growth** - leave some space for snapshots and system overhead
6. **Test recovery** - practice restoring from backups regularly

## References

- Longhorn Storage Requirements: https://longhorn.io/docs/latest/best-practices/#storage-configuration
- K3s Installation: https://docs.k3s.io/installation
- Linux Disk Management: `man parted`, `man fstab`, `man mount`
