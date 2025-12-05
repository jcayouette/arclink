# Hardware Inventory

This document provides a comprehensive inventory of all hardware components used in the ArcLink infrastructure deployment.

## Network Infrastructure

### Core Router

**MikroTik CCR2004-16G-2S+**

The MikroTik CCR2004-16G-2S+ serves as the primary routing platform for the cluster network. This enterprise-grade router features a quad-core ARM processor, 16 Gigabit Ethernet ports, and 2 SFP+ ports for high-speed fiber connectivity. With 4GB of RAM and support for advanced routing protocols, it provides the robust networking backbone required for distributed Kubernetes workloads.

![MikroTik CCR2004-16G-2S+ Router](placeholder-router.png)

**Key Specifications:**
- 16x Gigabit Ethernet ports
- 2x SFP+ 10Gbps ports
- 4GB DDR4 RAM
- Active cooling with dual fans
- RouterOS Level 6 license

### Network Patch Panel

**GeeekPi DeskPi RackMate Network Patch Panel (12-Port)**

A rack-mountable CAT6 patch panel providing structured cabling management for the cluster. The 12-port configuration accommodates all six Raspberry Pi nodes plus additional networking equipment, ensuring clean cable organization and easy maintenance access.

![Network Patch Panel](placeholder-patch-panel.png)

**Features:**
- 12x RJ45 CAT6 ports
- 10-inch rack mount form factor
- Professional cable management
- Gold-plated contacts

## Compute Platform

### Cluster Nodes

**Raspberry Pi 5 (8GB) - Quantity: 6**

The compute infrastructure consists of six Raspberry Pi 5 units, each equipped with 8GB of LPDDR4X RAM. These single-board computers form the foundation of the Kubernetes cluster, providing ARM64-based compute resources. The Raspberry Pi 5 features significant performance improvements over previous generations, including a quad-core Cortex-A76 processor running at 2.4GHz and dual 4Kp60 display support.

![Raspberry Pi 5 Cluster Nodes](placeholder-rpi5.png)

**Technical Specifications (per unit):**
- Broadcom BCM2712 quad-core Cortex-A76 @ 2.4GHz
- 8GB LPDDR4X-4267 SDRAM
- Dual 4Kp60 HDMI output
- 2x USB 3.0 ports, 2x USB 2.0 ports
- Gigabit Ethernet with PoE+ support (via HAT)
- PCIe 2.0 x1 interface
- GPIO 40-pin header

### Storage Expansion

**OEM Samsung MZALQ256B M.2 NVMe SSD - Quantity: 6**

Each cluster node is equipped with a 256GB Samsung M.2 NVMe SSD, providing fast persistent storage for the operating system and containerized applications. The PCIe 3.0 interface delivers significantly improved I/O performance compared to SD card-based storage, essential for database workloads and high-throughput applications.

![Samsung M.2 NVMe SSD](placeholder-nvme.png)

**Storage Specifications:**
- Capacity: 256GB per node (1.5TB total cluster storage)
- Form Factor: M.2 2242
- Interface: PCIe 3.0 x4 NVMe
- Sequential Read: Up to 2400 MB/s
- Sequential Write: Up to 950 MB/s

### PCIe Expansion Adapters

**GeeekPi N05 M.2 2242 PCIe to NVMe SSD Shield**

These PCIe expansion boards enable the connection of M.2 NVMe SSDs to the Raspberry Pi 5's PCIe interface. The compact design maintains the small form factor while providing enterprise-grade storage connectivity. Each adapter features proper power delivery and signal integrity for reliable NVMe operation.

![PCIe NVMe Adapter](placeholder-pcie-adapter.png)

### Power over Ethernet

**Waveshare PoE HAT (F) for Raspberry Pi 5 - Quantity: 6**

High-power PoE HATs provide both power delivery and network connectivity to each Raspberry Pi 5 node. These add-on boards support IEEE 802.3af/at standards and include active cooling with an integrated fan and metal heatsink. This solution eliminates the need for individual power adapters and simplifies cluster cabling.

![Waveshare PoE HAT](placeholder-poe-hat.png)

**Features:**
- IEEE 802.3af/at PoE+ compliant
- 5V/5A power output (25W)
- Temperature-controlled cooling fan
- Aluminum heatsink for enhanced thermal management
- Maintains access to GPIO pins

### Display Connectivity

**GeeekPi Micro HDMI to HDMI Adapter Board**

Compact adapter boards providing standard HDMI connectivity from the Raspberry Pi 5's micro HDMI ports. These adapters are designed for rack-mount environments and maintain compatibility with the DeskPi RackMate mounting system.

![HDMI Adapter Board](placeholder-hdmi-adapter.png)

## Rack Infrastructure

### Server Enclosure

**GeeekPi DeskPi RackMate T1 8U Server Rack**

A compact 8U rackmount enclosure housing the entire cluster infrastructure. The 10-inch form factor optimizes space efficiency while providing professional equipment mounting capabilities. The steel construction ensures durability and proper EMI shielding.

![DeskPi RackMate 8U Enclosure](placeholder-rack.png)

**Specifications:**
- Height: 8U (rack units)
- Width: 10 inches
- Steel frame construction
- Front and rear mounting rails
- Cable management features

### Power Distribution

**GeeekPi DC PDU Lite 7-Channel 0.5U**

A rack-mounted DC power distribution unit providing centralized power management for the cluster. The 7-channel configuration accommodates all auxiliary equipment requiring DC power. The 0.5U form factor maximizes space efficiency in the compact rack environment.

![DC PDU Power Distribution](placeholder-pdu.png)

**Capabilities:**
- 7 independent DC output channels
- Horizontal 0.5U rack mount design
- Compatible with DeskPi RackMate T1
- Overcurrent protection per channel

### Compute Shelf

**GeeekPi DeskPi RackMate SBC Shelf (10" 1U)**

A specialized 1U rack shelf designed for mounting single-board computers. This shelf securely holds multiple Raspberry Pi units in a rack-mountable format, providing proper airflow and easy access for maintenance. The design accommodates SBCs with attached HATs and cooling solutions.

![SBC Rack Shelf](placeholder-sbc-shelf.png)

## Support Equipment

### Development Tools

**FIDECO M.2 NVMe SATA SSD Docking Station**

A USB docking station supporting both M.2 NVMe and SATA SSDs, enabling rapid disk imaging, backup operations, and system preparation. This tool is essential for initial node provisioning and disaster recovery scenarios.

![SSD Docking Station](placeholder-docking.png)

**Features:**
- M.2 NVMe (PCIe & SATA) support
- 2.5" SATA SSD/HDD support
- USB 3.1 Gen 2 interface (10Gbps)
- Tool-free drive installation
- Offline clone function

**BENFEI SATA to USB Cable (2-in-1 USB-C/USB 3.0)**

Dual-interface SATA adapter cable providing flexible connectivity for 2.5" SATA drives. The 2-in-1 design supports both USB-C and USB-A connections, ensuring compatibility with various development workstations during system preparation and maintenance tasks.

![SATA to USB Cable](placeholder-sata-cable.png)

---

*Last Updated: December 5, 2025*
