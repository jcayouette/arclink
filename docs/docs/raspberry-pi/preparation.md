---
sidebar_position: 4
---

# System Preparation for K3s

Prepare your Raspberry Pi 5 for Arclink deployment.

## Overview

This guide covers OS installation, initial configuration, and optimization for running K3s and Arclink.

## Operating System Choice

### Recommended: Raspberry Pi OS Lite (64-bit)

**Why Raspberry Pi OS?**
- Official support
- Optimized for Pi hardware
- Well-tested with K3s
- Strong community support

**Download:**
```text
https://www.raspberrypi.com/software/operating-systems/
```

Choose: **Raspberry Pi OS Lite (64-bit)**
- No desktop environment
- Minimal resource usage
- Headless operation
- ~400MB download

### Alternative: Ubuntu Server

**Ubuntu Server 24.04 LTS**
- Familiar for Ubuntu users
- Enterprise support options
- Slightly higher resource usage

Both work equally well with K3s.

## Installation Methods

### Method 1: Raspberry Pi Imager (Recommended)

**Download Raspberry Pi Imager:**
- Windows: `https://downloads.raspberrypi.org/imager/imager_latest.exe`
- macOS: `https://downloads.raspberrypi.org/imager/imager_latest.dmg`
- Linux: `sudo apt install rpi-imager`

**Steps:**

1. Launch Raspberry Pi Imager
2. Click **Choose Device** → Raspberry Pi 5
3. Click **Choose OS** → Raspberry Pi OS (other) → Pi OS Lite (64-bit)
4. Click **Choose Storage** → Your microSD card
5. Click **Settings** (gear icon)

**Configure Settings:**
```text
Hostname: node0 (or your preferred name)
Username: your-username
Password: secure-password
Wireless LAN: (if using Wi-Fi)
  SSID: your-network
  Password: wifi-password
Locale: Your timezone
Keyboard: Your layout
Enable SSH: ✓ Use password authentication
```

6. Click **Save**
7. Click **Write**
8. Wait for completion

### Method 2: Manual Flash (Advanced)

```bash
# Download image
wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/...

# Extract
xz -d raspios-lite-arm64.img.xz

# Find SD card device
lsblk

# Write image (replace /dev/sdX)
sudo dd if=raspios-lite-arm64.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## First Boot Setup

### Boot from microSD

1. Insert prepared microSD card
2. **Do not connect NVMe yet** (for initial setup)
3. Connect Ethernet
4. Connect power
5. Wait ~60 seconds for first boot

### Find Your Pi

**Check your router's DHCP leases** or use:

```bash
# Scan network (from your computer)
nmap -sn 192.168.1.0/24

# or
sudo arp-scan --local | grep -i raspberry
```

### SSH Connection

```bash
ssh your-username@node0.local
# or
ssh your-username@192.168.1.xxx
```

Accept the SSH fingerprint.

## Initial Configuration

### Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Configure Locales

```bash
sudo raspi-config
```

Navigate:
- Localisation Options → Locale → Select your locale
- Localisation Options → Timezone → Select your timezone
- Localisation Options → Keyboard → Select your layout

### Set Static IP (Recommended)

Edit dhcpcd configuration:

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

Reboot to apply:

```bash
sudo reboot
```

Reconnect using the new IP:

```bash
ssh your-username@192.168.1.100
```

### Enable Container Features

Edit boot configuration:

```bash
sudo nano /boot/firmware/cmdline.txt
```

Add to the end of the existing line (don't create new lines):

```
cgroup_memory=1 cgroup_enable=memory
```

**Important**: Keep everything on ONE line!

Save and reboot:

```bash
sudo reboot
```

### Verify Cgroups

After reboot, verify:

```bash
cat /proc/cmdline | grep cgroup
```

Should show: `cgroup_memory=1 cgroup_enable=memory`

## NVMe SSD Setup

### Physical Installation

1. Power off the Pi
2. Attach M.2 HAT+ to GPIO header
3. Install NVMe SSD into M.2 slot
4. Secure with provided screw
5. Power on

### Verify Detection

```bash
lsblk
```

Should show:
```
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
mmcblk0     179:0    0 29.7G  0 disk 
├─mmcblk0p1 179:1    0  512M  0 part /boot/firmware
└─mmcblk0p2 179:2    0 29.2G  0 part /
nvme0n1     259:0    0  256G  0 disk 
```

### Boot from NVMe (Recommended)

**Benefits:**
- Faster performance
- Better reliability
- More capacity
- microSD as backup

**Clone to NVMe:**

```bash
# Install SD Copier
sudo apt install piclone

# Run as root
sudo piclone
```

Or use `rpi-clone`:

```bash
# Install rpi-clone
sudo apt install rpi-clone

# Clone to NVMe
sudo rpi-clone nvme0n1
```

**Update Boot Order:**

```bash
sudo raspi-config
```

Navigate:
- Advanced Options → Boot Order → NVMe/USB Boot
- Finish and reboot

**Alternative: Use as Data Drive**

If keeping boot on microSD:

```bash
# Format NVMe
sudo mkfs.ext4 /dev/nvme0n1 -L nvme-data

# Create mount point
sudo mkdir -p /mnt/nvme

# Get UUID
sudo blkid /dev/nvme0n1

# Add to fstab
sudo nano /etc/fstab
```

Add:
```
UUID=<your-uuid>  /mnt/nvme  ext4  defaults,noatime  0  2
```

Mount:
```bash
sudo mount -a
```

## System Optimization

### Disable Unnecessary Services

```bash
# Disable swap (K3s recommendation)
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo systemctl disable dphys-swapfile

# Disable Bluetooth (if not needed)
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
```

### Optimize for Server Use

```bash
# Reduce GPU memory (we don't need graphics)
sudo nano /boot/firmware/config.txt
```

Add:
```
gpu_mem=16
```

### Set CPU Governor

```bash
# Install CPU frequency tools
sudo apt install cpufrequtils

# Set performance governor
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils

# Apply
sudo systemctl restart cpufrequtils
```

### Enable Watchdog

```bash
# Enable hardware watchdog
echo 'dtparam=watchdog=on' | sudo tee -a /boot/firmware/config.txt

# Install watchdog daemon
sudo apt install watchdog

# Configure
sudo nano /etc/watchdog.conf
```

Uncomment:
```
watchdog-device = /dev/watchdog
max-load-1 = 24
```

Enable and start:
```bash
sudo systemctl enable watchdog
sudo systemctl start watchdog
```

## Network Configuration

### Set Hostname

```bash
# Set hostname
sudo hostnamectl set-hostname node0

# Update hosts file
sudo nano /etc/hosts
```

Change:
```
127.0.1.1       node0
```

### Configure mDNS (Optional)

For `.local` name resolution:

```bash
# Install Avahi
sudo apt install avahi-daemon avahi-utils

# Enable
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
```

Now accessible as `node0.local`

### Firewall Setup (Optional)

```bash
# Install UFW
sudo apt install ufw

# Allow SSH
sudo ufw allow 22/tcp

# Allow K3s
sudo ufw allow 6443/tcp  # K3s API
sudo ufw allow 8472/udp  # Flannel VXLAN
sudo ufw allow 10250/tcp # Kubelet

# Allow OpenTAK ports
sudo ufw allow 31080/tcp # Web UI
sudo ufw allow 31088/tcp # TCP CoT
sudo ufw allow 31089/tcp # SSL CoT

# Enable
sudo ufw enable
```

## Install Prerequisites

### Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group to take effect
exit
```

Reconnect and verify:

```bash
docker ps
```

### Git

```bash
sudo apt install git -y
```

## Temperature Monitoring

### Check Temperatures

```bash
# CPU temperature
vcgencmd measure_temp

# Create monitoring alias
echo 'alias temp="vcgencmd measure_temp"' >> ~/.bashrc
source ~/.bashrc
```

### Monitor During Load

```bash
# Install stress test
sudo apt install stress-ng

# Run stress test and monitor
stress-ng --cpu 4 --timeout 60s &
watch -n 1 vcgencmd measure_temp
```

**Safe operating temperatures:**
- Idle: 40-50°C
- Load: 60-75°C  
- Throttling: 80°C+

If exceeding 75°C under load, improve cooling.

## Multi-Node Setup

### For Each Additional Node

Repeat all steps, but change:
- Hostname: `node1`, `node2`, `node3`, etc.
- Static IP: `192.168.1.101`, `102`, `103`, etc.

### Create SSH Keys (On First Node)

```bash
# Generate key
ssh-keygen -t ed25519 -C "arclink-cluster"

# Copy to other nodes
ssh-copy-id user@node1
ssh-copy-id user@node2
ssh-copy-id user@node3
```

Test password-less SSH:
```bash
ssh node1 hostname
```

## Verification Checklist

Before proceeding to K3s installation:

- [ ] System updated
- [ ] Static IP configured
- [ ] Hostname set correctly
- [ ] Cgroups enabled (check `/proc/cmdline`)
- [ ] NVMe detected and configured
- [ ] Docker installed and working
- [ ] Git installed
- [ ] Temperature under control
- [ ] Network connectivity verified
- [ ] SSH keys configured (multi-node)

## Next Steps

With Pi prepared:
1. Install K3s (guide coming soon)
2. Configure storage (guide coming soon)
3. [Deploy Arclink](../guides/deploy.md)

## Troubleshooting

### Can't SSH

- Check network cable
- Verify IP address (check router)
- Confirm SSH enabled in Imager settings
- Try `ssh -v` for verbose debugging

### NVMe Not Detected

- Check physical connection
- Verify M.2 HAT+ properly seated
- Try different NVMe (some aren't compatible)
- Update bootloader: `sudo rpi-eeprom-update -a`

### High Temperature

- Verify active cooler connected
- Check fan is spinning
- Improve case ventilation
- Lower ambient temperature
- Consider heatsink upgrade

### Boot Issues

- Check SD card not corrupted
- Reflash if necessary
- Try different SD card
- Check power supply (minimum 27W)
