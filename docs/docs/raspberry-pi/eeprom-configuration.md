---
sidebar_position: 2
---

# EEPROM Configuration

Configure Raspberry Pi 5 EEPROM settings for optimal NVMe boot performance and cluster operation.

## Overview

The Raspberry Pi 5 EEPROM contains critical firmware that controls boot behavior, PCIe configuration, and hardware initialization. Proper EEPROM configuration is essential for:

- Booting directly from NVMe storage
- Optimizing PCIe Gen 3 performance
- Enabling network boot options
- Configuring power management
- Setting up console and debug options

## Prerequisites

- Raspberry Pi 5 with power supply
- Initial boot from microSD with Raspberry Pi OS
- Internet connection for EEPROM updates
- Terminal access (SSH or direct)

## Check Current EEPROM Version

First, verify your current EEPROM version:

```bash
sudo rpi-eeprom-update
```

Example output:

```text
BOOTLOADER: up to date
   CURRENT: Thu 18 Jan 13:49:46 UTC 2024 (1705584586)
    LATEST: Thu 18 Jan 13:49:46 UTC 2024 (1705584586)
   RELEASE: default (/lib/firmware/raspberrypi/bootloader-2712/default)
```

## Update EEPROM to Latest

Always update to the latest stable EEPROM before configuration:

```bash
# Update package lists
sudo apt update

# Install latest rpi-eeprom package
sudo apt install rpi-eeprom

# Check for updates
sudo rpi-eeprom-update

# If update available, apply it
sudo rpi-eeprom-update -a

# Reboot to apply
sudo reboot
```

## Extract Current Configuration

Before making changes, extract and review your current EEPROM configuration:

```bash
# Extract current config
sudo rpi-eeprom-config > current-bootconf.txt

# View configuration
cat current-bootconf.txt
```

## Key Configuration Parameters

### Boot Order Configuration

Configure boot device priority for NVMe-first boot:

```ini
[all]
BOOT_UART=1
POWER_OFF_ON_HALT=0
BOOT_ORDER=0xf416

# Boot order explanation:
# 0xf416 = Try NVMe, then SD card, then USB, then network
# 0xf461 = Try NVMe, then USB, then SD card, then network
# 0xf14  = Try NVMe, then SD card only
```

**Common Boot Order Values:**

| Value | Boot Sequence |
|-------|---------------|
| `0xf41` | SD card → USB → Network |
| `0xf14` | SD card → NVMe |
| `0xf416` | NVMe → SD card → USB → Network |
| `0xf461` | NVMe → USB → SD card → Network |
| `0x6` | NVMe only (no fallback) |

### PCIe Configuration

Enable PCIe Gen 3 for maximum NVMe performance:

```ini
# Enable PCIe Gen 3 (default is Gen 2)
PCIE_PROBE_RETRIES=10
```

**Note**: Some NVMe drives may have compatibility issues with Gen 3. If boot fails, remove this setting to fallback to Gen 2.

### Network Boot Settings

For PXE network boot in cluster environments:

```ini
# Enable network boot
NET_CONSOLE_ENABLED=1

# Set network boot timeout (in seconds)
NET_CONSOLE_TIMEOUT=30
```

### UART Console

Enable serial console for debugging:

```ini
# Enable UART console on GPIO pins
BOOT_UART=1
UART_BAUD=115200
```

### Power Management

Configure power button and halt behavior:

```ini
# Power button configuration
POWER_OFF_ON_HALT=0        # 0=blink LED, 1=cut power
WAKE_ON_GPIO=1              # Allow GPIO wake
```

## Recommended Configuration for Arclink

Create an optimized configuration file for Arclink deployments:

```bash
# Create custom configuration
sudo nano /tmp/arclink-bootconf.txt
```

Add the following configuration:

```ini
[all]
# Boot Configuration
BOOT_UART=1
BOOT_ORDER=0xf416
PCIE_PROBE_RETRIES=10

# Power Management
POWER_OFF_ON_HALT=0
WAKE_ON_GPIO=1

# Network Configuration
NET_CONSOLE_ENABLED=0

# Display Configuration
HDMI_DELAY=0

# USB Configuration
USB_MSD_PWR_OFF_TIME=0

# Firmware Options
FREEZE_VERSION=0
```

## Apply Custom Configuration

Apply your custom EEPROM configuration:

```bash
# Read current EEPROM
sudo rpi-eeprom-config > /tmp/current-bootconf.txt

# Apply new configuration
sudo rpi-eeprom-config --edit /tmp/arclink-bootconf.txt

# Or directly edit (opens nano)
sudo rpi-eeprom-config --edit

# Save and reboot
sudo reboot
```

## Verify Configuration

After reboot, verify the new configuration:

```bash
# Check applied configuration
sudo rpi-eeprom-config

# Verify boot order
sudo rpi-eeprom-config | grep BOOT_ORDER

# Check PCIe link speed (should show Gen 3)
sudo lspci -vv | grep LnkSta:
```

## NVMe Boot Setup

### Prepare NVMe Drive

Once EEPROM is configured for NVMe boot:

```bash
# List available storage devices
lsblk

# Identify your NVMe device (usually /dev/nvme0n1)
# Clone SD card to NVMe
sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 bs=4M status=progress

# Or use rpi-clone for automatic partition resize
sudo apt install rpi-clone
sudo rpi-clone nvme0n1
```

### Update /boot/firmware/config.txt on NVMe

After cloning, mount the NVMe boot partition and optimize settings:

```bash
# Mount NVMe boot partition
sudo mkdir -p /mnt/nvme-boot
sudo mount /dev/nvme0n1p1 /mnt/nvme-boot

# Edit config.txt
sudo nano /mnt/nvme-boot/config.txt
```

Add PCIe and NVMe optimizations:

```ini
# PCIe/NVMe Optimizations
dtparam=pciex1_gen=3

# Disable unnecessary interfaces to save power
dtparam=audio=off
camera_auto_detect=0
display_auto_detect=0

# GPU memory (minimize for headless)
gpu_mem=16

# Enable I2C for monitoring
dtparam=i2c_arm=on
```

### Test NVMe Boot

```bash
# Unmount NVMe
sudo umount /mnt/nvme-boot

# Remove SD card
# Power cycle the Pi
sudo reboot
```

The Pi should boot from NVMe. Verify with:

```bash
# Check root filesystem
df -h /

# Should show /dev/nvme0n1p2
```

## Troubleshooting

### Pi Won't Boot from NVMe

**Symptoms**: Green LED blinks specific pattern, boots to SD card instead

**Solutions**:

1. **Check BOOT_ORDER**:
   ```bash
   sudo rpi-eeprom-config | grep BOOT_ORDER
   ```

2. **Verify NVMe detection**:
   ```bash
   lsblk
   # Should show nvme0n1 device
   ```

3. **Try Gen 2 instead of Gen 3**:
   Remove `PCIE_PROBE_RETRIES=10` from EEPROM config

4. **Check NVMe compatibility**:
   Some NVMe drives have issues. Samsung 980/990, WD Blue SN580, and Crucial P3 are well-tested.

### NVMe Drive Not Detected

**Check PCIe link**:

```bash
sudo lspci
# Should show: NVMe SSD Controller

# Check link speed
sudo lspci -vv | grep -A 10 "Non-Volatile"
```

**Reseat the NVMe**:
- Power off completely
- Remove and reinsert NVMe drive
- Ensure secure connection

### Slow NVMe Performance

**Verify PCIe Gen 3**:

```bash
sudo lspci -vv | grep LnkSta:
# Should show: Speed 8GT/s (Gen 3)
```

**If showing Gen 2**:

1. Add to `/boot/firmware/config.txt`:
   ```ini
   dtparam=pciex1_gen=3
   ```

2. Reboot and verify again

### EEPROM Update Failed

**Recovery steps**:

```bash
# Force recovery mode
sudo rpi-eeprom-update -d -f /lib/firmware/raspberrypi/bootloader-2712/default/pieeprom-2024-01-18.bin

# If completely bricked, use USB boot recovery
# Download recovery image from raspberrypi.com
```

## EEPROM Version History

**Key versions for Pi 5**:

| Date | Version | Changes |
|------|---------|---------|
| 2024-01-18 | Latest stable | Improved NVMe compatibility |
| 2023-12-06 | Initial | First Pi 5 production EEPROM |

Always use the latest stable version for best compatibility.

## Advanced Configuration

### Custom Boot Screens

Disable rainbow splash screen:

```ini
DISABLE_SPLASH=1
```

### Boot Diagnostics

Enable verbose boot for debugging:

```ini
BOOT_UART=1
UART_LOG=1
```

### Network Boot (PXE)

For centralized cluster management:

```ini
BOOT_ORDER=0xf421    # Network boot priority
TFTP_IP=192.168.1.1  # TFTP server
TFTP_PREFIX=0        # Boot file prefix
```

## Configuration Best Practices

1. **Always backup** current config before changes
2. **Test on one node** before deploying to cluster
3. **Document** any custom settings
4. **Verify** after each change with `sudo rpi-eeprom-config`
5. **Keep EEPROM updated** to latest stable
6. **Use consistent** settings across cluster nodes

## Next Steps

With EEPROM properly configured:

1. [Initial Setup](./initial-setup.md) - Configure OS and system settings
2. [Preparation](./preparation.md) - Optimize for Kubernetes
3. Deploy K3s cluster

## References

- [Official EEPROM Documentation](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-bootloader-configuration)
- [Pi 5 PCIe Configuration](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#pcie-gen-3-0)
- [Boot Modes](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-5-boot-flow)
