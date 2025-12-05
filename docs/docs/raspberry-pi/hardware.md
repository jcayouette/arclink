---
sidebar_position: 1
---

# Hardware Requirements

Complete hardware guide for building Raspberry Pi 5-based Arclink systems, covering both stationary rack installations and mobile van deployments.

## Deployment Types

This guide covers hardware requirements for two primary deployment scenarios:

- **Stationary Rack Installation**: Fixed infrastructure for lab, office, or data center environments
- **Mobile Van Deployment**: Rugged, portable systems for tactical field operations

Choose the configuration that matches your use case, or use this guide to plan both.

## Raspberry Pi 5 Specifications

### Recommended Models

**Raspberry Pi 5 8GB** (Recommended)
- 8GB LPDDR4X RAM
- Quad-core ARM Cortex-A76 @ 2.4GHz
- Better performance headroom
- Ideal for single-node or cluster deployments

**Raspberry Pi 5 4GB** (Minimum)
- 4GB LPDDR4X RAM
- Same CPU as 8GB model
- Suitable for testing or cluster member
- May need swap for heavy loads

### Why Raspberry Pi 5?

- **Performance**: 2-3x faster than Pi 4
- **PCIe Support**: Native NVMe via M.2 HAT+
- **Power Efficiency**: Better performance per watt
- **Availability**: Easier to source than Pi 4
- **Future-proof**: Support for upcoming features

## Essential Components

### For Each Node

| Component | Specification | Purpose | Est. Cost |
|-----------|--------------|---------|-----------|
| Raspberry Pi 5 | 8GB RAM preferred | Main compute | $80 |
| M.2 HAT+ | Official Pi M.2 HAT+ | NVMe connection | $12 |
| NVMe SSD | 256GB+ NVMe M.2 | Fast storage | $25-40 |
| Power Supply | 27W USB-C PD | Reliable power | $12 |
| Case | With active cooling | Thermal management | $15-30 |
| microSD Card | 32GB Class 10 | Boot only | $8 |
| Ethernet Cable | Cat6 or better | Network connectivity | $5 |

**Total per node**: ~$160-190

## Storage Options

### Recommended: NVMe SSD

**Why NVMe?**
- 10x faster than microSD
- Better random I/O for databases
- More reliable for production
- Lower latency

**Recommended SSDs:**
- Samsung 980/990 EVO (250GB-500GB)
- WD Blue SN580 (250GB-500GB)
- Crucial P3 (250GB-500GB)
- Kingston NV2 (250GB-500GB)

**Avoid:**
- SATA M.2 (won't work with Pi M.2 HAT+)
- High-power NVMe (thermal issues)
- No-name brands (reliability concerns)

### Budget Option: microSD

**For Testing Only**
- Use Class A2 or U3 cards
- 64GB minimum
- Expect slower performance
- Not recommended for production

## Networking Hardware

### Single Node Setup

**Minimum:**
- 1 Ethernet cable (to router/switch)
- Existing network infrastructure

### Cluster Setup (3+ Nodes)

**Required:**
- Gigabit switch (unmanaged okay)
- Ethernet cables (one per node + 1 uplink)
- Optional: Managed switch for VLANs

**Recommended Switches:**
- NETGEAR GS108 (8-port, unmanaged) - $30
- TP-Link TL-SG108 (8-port, unmanaged) - $25
- Ubiquiti UniFi Switch Lite 8 (managed) - $109
- MikroTik CSS326-24G (24-port, budget) - $140

## Power Solutions

### Individual Power Supplies

**Per Node:**
- Official Raspberry Pi 27W USB-C PSU
- or equivalent USB-C PD 27W+ supply

**Pros:**
- Simple to deploy
- Redundant failure
- Easy to troubleshoot

**Cons:**
- Multiple wall outlets needed
- Cable clutter
- No centralized management

### Multi-Port USB-C Charger

**Example: Anker 735 (65W, 3-port)**
- Powers 2 Pi 5s simultaneously
- Space-efficient
- ~$45

**Pros:**
- Fewer wall outlets
- Cleaner setup
- Better cable management

**Cons:**
- Single point of failure
- May not power 3+ Pis

### PoE+ Solution

**Waveshare PoE+ HAT for Pi 5**
- IEEE 802.3at compliant
- 25.5W power delivery
- Integrated fan

**Requirements:**
- PoE+ switch (30W per port)
- More expensive upfront
- ~$35 per HAT

**Pros:**
- Single cable per node (data + power)
- Cleaner installation
- Centralized power management
- Professional appearance

**Cons:**
- Higher initial cost
- Need PoE+ switch
- More complex troubleshooting

## Cooling Solutions

Raspberry Pi 5 runs hot under load. Proper cooling is essential.

### Required: Active Cooling

**Official Active Cooler** (~$5)
- Clips onto Pi 5
- PWM fan control
- Good for single node

**Pimoroni NVMe Base** (~$12-15)
- Combines case + M.2 + cooling
- Compact design
- Great for desktop use

**Argon NEO 5 Case** (~$30)
- Aluminum case
- Passive + active cooling
- Professional appearance
- Good thermal performance

### Cluster Cooling

**Rack-Mount Solutions:**
- 120mm case fans
- Directed airflow
- Temperature monitoring
- Dust filters

**Environmental:**
- Ambient temperature &lt;25°C (77°F)
- Good ventilation
- Keep out of direct sunlight
- Monitor temps in k3s

## Cluster Building Hardware

### 3-Node Cluster

**Additional Items:**
- Cluster case/rack
- Cable management
- Labeling supplies

**Cluster Case Options:**

**Budget: DIY**
- Laser-cut acrylic layers
- 3D-printed mounts
- Standoffs and screws
- ~$20-30 materials

**Commercial:**
- GeeekPi 4-layer cluster case - $40
- C4Labs Cloudlet case - $80
- Uctronics 19" rack mount - $90

### 5+ Node Cluster

**Professional Options:**
- MyElectronics.nl Raspberry Pi Rack
- Custom 3D-printed rack
- Modified server rack shelves

**Considerations:**
- Power distribution
- Cable routing
- Serviceability
- Cooling airflow

## Optional Accessories

### Nice to Have

**USB-to-Serial Cable** ($10)
- UART debugging
- Headless troubleshooting
- Console access

**SD Card Reader** ($10)
- Flash images
- Backup cards
- Emergency recovery

**Label Maker** ($20)
- Node identification
- Cable labeling
- Professional appearance

**Power Meter** ($15)
- Monitor power consumption
- Capacity planning
- Cost analysis

**Temperature Sensors** ($10)
- Ambient monitoring
- Alert on overheating
- Data center monitoring

## Stationary Rack Installation

### Complete Bill of Materials

This section documents the production hardware inventory for a 6-node stationary cluster installation.

#### Network Infrastructure

**MikroTik CCR2004-16G-2S+ Router**

Enterprise-grade routing platform providing the network backbone for the cluster. Features 16 Gigabit Ethernet ports, 2 SFP+ 10Gbps ports, quad-core ARM processor, 4GB DDR4 RAM, and active cooling with dual fans.

**GeeekPi DeskPi RackMate Network Patch Panel (12-Port)**

Rack-mountable CAT6 patch panel for structured cabling management. The 12-port configuration accommodates all six nodes plus networking equipment with gold-plated contacts and professional cable organization.

#### Compute Nodes (Quantity: 6)

**Raspberry Pi 5 (8GB)**

Six units form the Kubernetes cluster foundation with quad-core Cortex-A76 @ 2.4GHz, 8GB LPDDR4X-4267 RAM, dual 4Kp60 HDMI, PCIe 2.0 x1 interface, and Gigabit Ethernet with PoE+ support.

**OEM Samsung MZALQ256B M.2 NVMe SSD (256GB per node)**

Enterprise storage providing 1.5TB total cluster capacity. PCIe 3.0 x4 NVMe interface with sequential read up to 2400 MB/s and write up to 950 MB/s.

**GeeekPi N05 M.2 2242 PCIe to NVMe SSD Shield**

PCIe expansion boards enabling M.2 NVMe connectivity to the Pi 5's PCIe interface while maintaining compact form factor.

**Waveshare PoE HAT (F) for Raspberry Pi 5**

High-power PoE HATs providing IEEE 802.3af/at compliant power (5V/5A, 25W) and network connectivity. Features temperature-controlled cooling fan and aluminum heatsink.

**GeeekPi Micro HDMI to HDMI Adapter Board**

Compact adapters providing standard HDMI connectivity from micro HDMI ports, designed for rack-mount compatibility.

#### Rack Infrastructure

**GeeekPi DeskPi RackMate T1 8U Server Rack**

Compact 8U, 10-inch rackmount enclosure with steel frame construction, front and rear mounting rails, and integrated cable management.

**GeeekPi DC PDU Lite 7-Channel 0.5U**

Rack-mounted DC power distribution with 7 independent channels, horizontal 0.5U design, and overcurrent protection per channel.

**GeeekPi DeskPi RackMate SBC Shelf (10" 1U)**

Specialized 1U shelf for mounting multiple Raspberry Pi units with proper airflow and maintenance access.

#### Support Equipment

**FIDECO M.2 NVMe SATA SSD Docking Station**

USB 3.1 Gen 2 (10Gbps) docking station supporting M.2 NVMe and SATA SSDs for rapid disk imaging, backup, and provisioning.

**BENFEI SATA to USB Cable (2-in-1 USB-C/USB 3.0)**

Dual-interface SATA adapter cable for 2.5" SATA drives, compatible with USB-C and USB-A connections.

## Mobile Van Deployment

For tactical field operations, mobile deployments require additional considerations for power, ruggedization, and environmental protection. See [Mobile Deployment Guide](./mobile-deployment.md) for complete specifications.

### Key Differences from Stationary

**Rugged Enclosure**
- Shock-mounted components
- Weatherproof sealing with active ventilation
- Vibration dampening
- EMI shielding

**Power Systems**
- 12V/24V DC input from vehicle electrical
- Battery backup with automatic switching
- Solar charging integration
- Power consumption monitoring

**Connectivity**
- Cellular LTE/5G backup
- Satellite communications integration
- GPS timing for off-grid operation
- RF shielding considerations

**Environmental**
- Extended temperature range (-20°C to 60°C)
- Humidity and dust protection
- Shock and vibration resistance
- Thermal management for enclosed spaces

### Portable Build Options

**Rugged Enclosure**

**Pelican Case Options:**
- Pelican 1120 (single Pi)
- Pelican 1300 (3-Pi cluster)
- Pelican 1450 (5-Pi cluster)

**Considerations:**
- Shock mounting
- Ventilation (don't seal completely)
- Cable management
- Battery backup options

**Battery Power**

**USB-C Power Banks:**
- Anker PowerCore 26800 PD (45W)
- RAVPower 20000mAh PD Pioneer (60W)
- Goal Zero Sherpa 100AC

**Runtime Estimates:**
- Single Pi 5: 3-6 hours (typical load)
- 3-Pi cluster: 1-2 hours
- Add solar for extended operation

**GPS/Timing**

**GPS HATs:**
- Adafruit Ultimate GPS HAT
- Uputronics GPS HAT
- For precise time sync
- Useful for off-grid operation

## Shopping List Templates

### Single Node (Development)

```text
[ ] Raspberry Pi 5 8GB - $80
[ ] Official M.2 HAT+ - $12
[ ] 256GB NVMe SSD - $30
[ ] Official 27W PSU - $12
[ ] Official Active Cooler - $5
[ ] 32GB microSD - $8
[ ] Cat6 Ethernet cable - $5
[ ] Case (optional) - $20

Total: ~$172
```

### 3-Node Cluster (Production)

```text
[ ] 3x Raspberry Pi 5 8GB - $240
[ ] 3x Official M.2 HAT+ - $36
[ ] 3x 512GB NVMe SSD - $120
[ ] 3x Official 27W PSU - $36
[ ] 3x Active cooler - $15
[ ] 3x 32GB microSD - $24
[ ] 8-port Gigabit switch - $30
[ ] 4x Cat6 cables - $20
[ ] Cluster case - $50
[ ] Cable management - $15

Total: ~$586
```

### Mobile Command Center

```text
[ ] 3x Raspberry Pi 5 8GB - $240
[ ] 3x Official M.2 HAT+ - $36
[ ] 3x 512GB NVMe SSD - $120
[ ] 3x 27W PSU or PoE+ HATs - $40-100
[ ] Pelican 1300 case - $80
[ ] PoE+ switch (optional) - $100
[ ] 100W USB-C power bank - $100
[ ] GPS HAT - $60
[ ] Shock mounts - $30
[ ] Cables and misc - $40

Total: ~$806-866
```

## Next Steps

With hardware assembled:
1. [Prepare Raspberry Pi](./preparation.md)
2. Install K3s (guide coming soon)
3. [Deploy Arclink](../guides/deploy.md)
