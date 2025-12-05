---
sidebar_position: 3
---

# Initial Setup

Complete initial configuration of Raspberry Pi 5 nodes for Arclink cluster deployment.

## Overview

This guide covers the first-boot configuration and optimization steps required before deploying Kubernetes. These steps should be performed on each node in your cluster.

## Prerequisites

- Raspberry Pi 5 with [EEPROM configured](./eeprom-configuration.md)
- NVMe SSD or microSD card with OS installed
- Network connectivity
- SSH access or keyboard/monitor

## Operating System Installation

### Recommended: Raspberry Pi OS Lite (64-bit)

Download and install using Raspberry Pi Imager:

```bash
# On your workstation, download Raspberry Pi Imager
# https://www.raspberrypi.com/software/

# Or on Linux:
sudo apt install rpi-imager
```

**Image Selection**:
- Operating System: Raspberry Pi OS Lite (64-bit)
- Storage: Select your microSD or USB-connected NVMe
- Advanced Options (⚙️ icon):
  - Set hostname: `node0`, `node1`, etc.
  - Enable SSH: Use password or SSH key
  - Set username/password
  - Configure wireless LAN (if needed)
  - Set locale settings

### Alternative: Ubuntu Server 24.04 LTS

```bash
# Download Ubuntu Server for Raspberry Pi
# https://ubuntu.com/download/raspberry-pi

# Flash using Raspberry Pi Imager or dd
sudo dd if=ubuntu-24.04-preinstalled-server-arm64+raspi.img of=/dev/sdX bs=4M status=progress
```

## First Boot Configuration

### Initial Login

Connect via SSH or terminal:

```bash
# SSH to node (replace with your hostname/IP)
ssh acme@node0.local
# Or use IP: ssh acme@192.168.1.100
```

### Update System

Always start with a full system update:

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt full-upgrade -y

# Install essential tools
sudo apt install -y \
  vim \
  git \
  curl \
  wget \
  htop \
  net-tools \
  iotop \
  lsof \
  rsync \
  screen \
  tmux

# Reboot to apply kernel updates
sudo reboot
```

## Network Configuration

### Set Static IP Address

For cluster nodes, static IPs are essential:

**Using NetworkManager (Raspberry Pi OS Bookworm)**:

```bash
# List connections
nmcli connection show

# Configure static IP (adjust values for your network)
sudo nmcli connection modify "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "192.168.1.1,8.8.8.8"

# Apply changes
sudo nmcli connection up "Wired connection 1"
```

**Using dhcpcd (older systems)**:

```bash
sudo nano /etc/dhcpcd.conf
```

Add at the end:

```bash
# Static IP configuration
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

**Verify connectivity**:

```bash
# Check IP address
ip addr show eth0

# Test internet connectivity
ping -c 4 8.8.8.8

# Test DNS resolution
ping -c 4 google.com
```

### Set Hostname

Set a descriptive hostname for each node:

```bash
# Set hostname (e.g., node0, node1, node2)
sudo hostnamectl set-hostname node0

# Verify
hostnamectl
```

Update `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Ensure first line shows:

```text
127.0.1.1       node0
```

Add cluster nodes:

```text
192.168.1.100   node0
192.168.1.101   node1
192.168.1.102   node2
192.168.1.103   node3
192.168.1.104   node4
192.168.1.105   node5
```

## Security Hardening

### SSH Configuration

Harden SSH for production use:

```bash
sudo nano /etc/ssh/sshd_config
```

Recommended settings:

```bash
# Disable root login
PermitRootLogin no

# Use key-based authentication only
PubkeyAuthentication yes
PasswordAuthentication no

# Disable empty passwords
PermitEmptyPasswords no

# Limit login attempts
MaxAuthTries 3
MaxSessions 2

# Set idle timeout
ClientAliveInterval 300
ClientAliveCountMax 2
```

**Setup SSH keys** (if not done during imaging):

```bash
# On your workstation
ssh-keygen -t ed25519 -C "arclink-cluster"

# Copy to each node
ssh-copy-id acme@node0.local
ssh-copy-id acme@node1.local
# ... repeat for all nodes
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### Firewall Configuration

Install and configure UFW (Uncomplicated Firewall):

```bash
# Install UFW
sudo apt install -y ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow Kubernetes ports (will be needed for K3s)
sudo ufw allow 6443/tcp    # K3s API server
sudo ufw allow 10250/tcp   # Kubelet
sudo ufw allow 2379:2380/tcp  # etcd (master only)
sudo ufw allow 30000:32767/tcp # NodePort services

# Allow flannel (CNI)
sudo ufw allow 8472/udp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### Automatic Security Updates

Enable unattended security updates:

```bash
sudo apt install -y unattended-upgrades

# Configure
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Ensure these lines are uncommented:

```bash
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};

Unattended-Upgrade::Automatic-Reboot "false";
```

## Performance Tuning

### Disable Unnecessary Services

Free up resources by disabling unused services:

```bash
# Disable Bluetooth
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth

# Disable WiFi (if using ethernet)
sudo rfkill block wifi

# Disable ModemManager (not needed)
sudo systemctl disable ModemManager
sudo systemctl stop ModemManager

# Disable avahi-daemon (if not using mDNS)
sudo systemctl disable avahi-daemon
sudo systemctl stop avahi-daemon
```

### Memory and Swap Configuration

Optimize for containerized workloads:

```bash
# Reduce swappiness (prefer RAM over swap)
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Increase file handles
echo "fs.file-max=100000" | sudo tee -a /etc/sysctl.conf

# Optimize network
echo "net.core.somaxconn=1024" | sudo tee -a /etc/sysctl.conf
echo "net.core.netdev_max_backlog=5000" | sudo tee -a /etc/sysctl.conf

# Apply immediately
sudo sysctl -p
```

### Configure Swap

For 8GB nodes, a small swap is insurance:

```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify
free -h
```

### GPU Memory Reduction

For headless operation, minimize GPU memory:

```bash
sudo nano /boot/firmware/config.txt
```

Add or modify:

```ini
# Minimal GPU memory for headless
gpu_mem=16

# Disable unnecessary hardware
dtparam=audio=off
camera_auto_detect=0
display_auto_detect=0

# Enable I2C for monitoring
dtparam=i2c_arm=on

# PCIe Gen 3 (if not already set)
dtparam=pciex1_gen=3
```

Reboot to apply:

```bash
sudo reboot
```

## Storage Optimization

### Verify NVMe Performance

Test NVMe read/write speeds:

```bash
# Install hdparm
sudo apt install -y hdparm

# Test read speed
sudo hdparm -t /dev/nvme0n1

# Should show ~400+ MB/sec for sequential read

# More detailed test with dd
sudo dd if=/dev/nvme0n1 of=/dev/null bs=1M count=1000 status=progress

# Write test (creates 1GB file)
dd if=/dev/zero of=~/test.img bs=1M count=1000 oflag=direct status=progress
rm ~/test.img
```

### Filesystem Optimization

Optimize ext4 for SSD/NVMe:

```bash
# Check current mount options
mount | grep nvme0n1p2

# Add to /etc/fstab (if not present)
sudo nano /etc/fstab
```

Ensure root partition has:

```
/dev/nvme0n1p2  /  ext4  defaults,noatime,nodiratime  0  1
```

Apply:

```bash
sudo mount -o remount /
```

### Enable TRIM

Enable periodic TRIM for SSD health:

```bash
# Enable fstrim timer
sudo systemctl enable fstrim.timer
sudo systemctl start fstrim.timer

# Check status
sudo systemctl status fstrim.timer

# Manual TRIM (test)
sudo fstrim -v /
```

## Monitoring Setup

### Install Monitoring Tools

```bash
# System monitoring
sudo apt install -y htop iotop

# Temperature monitoring
sudo apt install -y lm-sensors

# Disk monitoring
sudo apt install -y smartmontools
```

### Check System Temperatures

```bash
# CPU temperature
vcgencmd measure_temp

# Create monitoring alias
echo 'alias temp="vcgencmd measure_temp"' >> ~/.bashrc
source ~/.bashrc

# Now just type: temp
```

### Monitor CPU Frequency

```bash
# Check current frequency
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# Watch all cores
watch -n 1 'cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq'
```

## Time Synchronization

Ensure accurate time sync across cluster:

```bash
# Install chrony (better than ntpd for intermittent connectivity)
sudo apt install -y chrony

# Configure
sudo nano /etc/chrony/chrony.conf
```

Add reliable time servers:

```
# Use Google time servers
server time1.google.com iburst
server time2.google.com iburst
server time3.google.com iburst
server time4.google.com iburst

# Allow other nodes to sync (master node only)
allow 192.168.1.0/24
```

Restart and verify:

```bash
sudo systemctl restart chrony
chronyc tracking
chronyc sources
```

## Cluster Preparation

### Container Runtime Prerequisites

Prepare for K3s installation:

```bash
# Enable required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Verify
lsmod | grep overlay
lsmod | grep br_netfilter

# Sysctl params for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply immediately
sudo sysctl --system
```

### Disable Swap (if using K8s without swap support)

Some Kubernetes setups require swap disabled:

```bash
# Disable current swap
sudo swapoff -a

# Comment out swap in fstab
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verify
free -h
```

**Note**: K3s can run with swap enabled if configured properly.

## Node Labeling Strategy

Plan node labels for workload placement:

```bash
# Examples:
# node0 - master, control-plane
# node1-5 - workers

# Labels to apply later:
# node-role.kubernetes.io/master
# node-role.kubernetes.io/worker
# arclink.io/storage=nvme
# arclink.io/zone=rack1
```

Document your labeling scheme for consistency.

## Validation Checklist

Before proceeding to K3s deployment, verify:

```bash
# System information
hostnamectl
uname -a

# Network configuration
ip addr show
ping -c 4 8.8.8.8

# Storage
lsblk
df -h

# Memory
free -h

# Temperature (should be under 70°C at idle)
vcgencmd measure_temp

# Services
systemctl list-units --state=running

# Kernel modules
lsmod | grep -E 'overlay|br_netfilter'

# Time sync
timedatectl
```

## Backup Configuration

Before proceeding, create a backup image:

```bash
# On your workstation, backup the NVMe
# Connect via USB adapter
sudo dd if=/dev/sdX of=node0-configured.img bs=4M status=progress

# Compress to save space
gzip node0-configured.img

# Clone this image to other nodes for consistency
```

## Next Steps

With all nodes configured:

1. [Deploy K3s Cluster](../guides/deploy.md)
2. Install Longhorn storage
3. Deploy Arclink applications

## Troubleshooting

### SSH Connection Refused

```bash
# Check SSH service
sudo systemctl status ssh

# Restart if needed
sudo systemctl restart ssh

# Check firewall
sudo ufw status
```

### No Internet Connectivity

```bash
# Check interface
ip link show

# Verify gateway
ip route show

# Test DNS
nslookup google.com

# Check resolv.conf
cat /etc/resolv.conf
```

### High CPU Temperature

```bash
# Check temperature
vcgencmd measure_temp

# Verify cooling fan
# Should hear fan running under load

# Check throttling
vcgencmd get_throttled
# 0x0 = no throttling (good)
# Other values indicate thermal or voltage issues
```

### Slow NVMe Performance

```bash
# Verify PCIe Gen 3
sudo lspci -vv | grep LnkSta:

# Should show: Speed 8GT/s

# If Gen 2, add to /boot/firmware/config.txt:
# dtparam=pciex1_gen=3
```

## References

- [Raspberry Pi OS Documentation](https://www.raspberrypi.com/documentation/computers/os.html)
- [K3s Requirements](https://docs.k3s.io/installation/requirements)
- [Raspberry Pi Performance Tuning](https://www.raspberrypi.com/documentation/computers/config_txt.html)
