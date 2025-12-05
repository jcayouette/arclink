---
sidebar_position: 5
---

# Mobile Van Deployment

Complete guide for deploying Arclink in mobile tactical environments using vehicle-integrated Raspberry Pi clusters.

## Overview

Mobile van deployments extend Arclink's capabilities to field operations, enabling resilient tactical communications in remote locations. This guide covers the unique requirements for ruggedized, vehicle-integrated cluster installations.

## Design Considerations

### Mission Requirements

**Typical Use Cases**:
- Emergency response command centers
- Disaster recovery operations
- Military field operations
- Remote area connectivity
- Event communications
- Scientific field research

**Key Requirements**:
- Reliable operation during vehicle motion
- Extended off-grid operation (8+ hours)
- Rapid deployment and teardown
- Environmental resilience
- Minimal maintenance

## Architecture Options

### Option 1: Compact 3-Node Cluster

**Best for**: Single vehicle, limited space, basic services

```text
Compute: 3x Raspberry Pi 5 (8GB)
Storage: 3x 256GB NVMe
Power: 12V DC with battery backup
Enclosure: Pelican 1400 or custom rack
Network: Integrated LTE/5G router
```

**Capabilities**:
- K3s with basic HA
- Core Arclink services
- 50-100 concurrent users
- 6-8 hour battery runtime

### Option 2: Full 6-Node Cluster

**Best for**: Command vehicles, extended operations

```text
Compute: 6x Raspberry Pi 5 (8GB)
Storage: 6x 512GB NVMe
Power: 12V DC with solar charging
Enclosure: Custom 19" rack mount
Network: Dual LTE/5G + Starlink
```

**Capabilities**:
- Full K3s HA cluster
- Complete Arclink suite
- 200+ concurrent users
- 12+ hour battery runtime
- Real-time video streaming

### Option 3: Distributed Multi-Vehicle

**Best for**: Large operations, redundant coverage

```text
Primary Vehicle:
- 6-node control cluster
- Network management
- Data aggregation

Secondary Vehicles (2+):
- 3-node edge clusters
- Local services
- Mesh networking
```

## Power Systems

### Vehicle Integration

#### 12V DC Power Distribution

Most tactical vehicles provide 12V DC power:

```text
Vehicle Battery (12V)
    ↓
Voltage Regulator (12V → 5V @ 150W)
    ↓
DC Distribution Board (7-channel PDU)
    ↓
USB-C PD Adapters (6x @ 25W each)
    ↓
Raspberry Pi 5 nodes (via USB-C)
```

**Recommended Components**:

**Voltage Converter**: 
- Mean Well SD-150C-5 (12V → 5V, 150W, 30A)
- Enclosed design, wide input range (9-18V)
- High efficiency (87%)
- ~$40

**DC Distribution**:
- GeeekPi DC PDU Lite 7-Channel (from stationary setup)
- Or custom distribution board with fuses
- Individual circuit protection

**USB-C PD Boards**:
- USB-C PD 3.0 trigger boards (5V 5A mode)
- 6x units, one per Pi
- ~$5 each

#### Battery Backup System

**Primary Battery Bank**:

```text
LiFePO4 Battery: 12V 200Ah (2560Wh)
- Brand: Battle Born, Renogy, or Victron
- Cost: $800-1200
- Runtime: ~15-20 hours full load
- Cycle life: 3000-5000 cycles
```

**Battery Management**:
- Smart BMS (Battery Management System)
- Low voltage disconnect (LVD) protection
- Temperature monitoring
- State of charge display

**Charging Sources**:

1. **Vehicle alternator** (while driving):
   - DC-DC charger (30A): Renogy DCC50S
   - Charges at 100-400W
   - ~$200

2. **Solar panels** (deployed operations):
   - 2x 200W panels (400W total)
   - MPPT charge controller: Victron SmartSolar 100/30
   - Deployment stands or vehicle roof mount
   - ~$600 total

3. **Shore power** (when available):
   - AC → DC charger: Victron Blue Smart IP65 (25A)
   - ~$150

**Power Consumption**:

```text
Component Load:
- 6x Raspberry Pi 5: ~90W (15W each)
- Network equipment: ~25W
- Cooling fans: ~15W
- Peripherals: ~20W
Total: ~150W continuous

Battery runtime (200Ah @ 12V):
2560Wh / 150W = ~17 hours

With 50% DoD (battery health):
~8.5 hours runtime
```

### Power Management

**Automatic Switching**:

```bash
# Install UPS monitoring
sudo apt install nut

# Configure for multi-input
# Priority: Vehicle → Battery → Solar
```

**Low Power Mode**:

```bash
# Reduce CPU frequency when on battery
sudo nano /etc/systemd/system/battery-saver.service
```

Add power-saving governor:

```ini
[Unit]
Description=Battery Saver Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpufreq-set -g powersave

[Install]
WantedBy=multi-user.target
```

## Network Connectivity

### Primary Connection: Cellular

**LTE/5G Router Options**:

1. **Peplink MAX Transit Duo** (Recommended)
   - Dual LTE modems (carrier aggregation/load balancing)
   - SpeedFusion VPN bonding
   - WiFi-as-WAN
   - GPS tracking
   - Cost: $1,000-1,500

2. **Mikrotik wAP LTE kit**
   - Budget option
   - Single LTE modem
   - Outdoor rated (IP66)
   - Cost: $150

3. **Sierra Wireless RV50X**
   - Industrial LTE gateway
   - Wide temperature range
   - DIN rail mount
   - Cost: $400

**Antenna Considerations**:
- External MIMO antennas (roof/mag mount)
- 5-10dBi gain
- Weatherproof connectors
- Brands: Parsec, Panorama, Poynting

### Backup: Satellite

**Starlink Mobile**:
- High-speed global coverage
- Flat High Performance dish
- 12V DC powered (60-150W)
- Cost: $2,500 equipment + $250/month
- Best for static deployments

**Inmarsat BGAN**:
- Portable terminals (Explorer 710)
- Lower bandwidth (384kbps-650kbps)
- True global coverage
- Cost: $1,500 + usage fees
- Emergency backup only

### Mesh Networking

**LoRa for Inter-Vehicle**:

```text
Primary Vehicle (Gateway)
    ↓ LoRa (868/915MHz)
Secondary Vehicles (Nodes)
    ↓ LoRa
Mobile Field Units
```

**Hardware**:
- RAK Wireless WisGate Edge (gateway): $150
- RAK2245 Pi Hat (nodes): $80
- Range: 5-10km line of sight

### WiFi Access Point

**Outdoor Coverage**:
- Ubiquiti UniFi FlexHD
- 2.4/5GHz, weather resistant
- PoE powered
- Magnetic mount for vehicle roof
- Cost: $180

## Enclosure and Mounting

### Rugged Enclosure Design

**Option 1: Pelican Case (3-node)**

**Model**: Pelican 1400

```text
Internal Layout:
┌─────────────────────────────┐
│  3x Pi 5 (stacked)          │
│  Network switch             │
│  Power distribution         │
│  Cable management           │
└─────────────────────────────┘

Modifications:
- Custom foam cutouts
- Ventilation ports (IP65 vents)
- External antenna connections
- Shock-mounted components
```

**Ventilation**:
- 2x 80mm intake fans (filtered)
- 1x 80mm exhaust fan
- IP65 rated vent plugs (Gore-Tex)
- Temperature-controlled (30°C on, 25°C off)

**Option 2: 19" Rack Mount (6-node)**

**Enclosure**: 6U shock-mount rack case

```text
Rack Layout (top to bottom):
1U - Network switch + router
1U - Power distribution
2U - SBC shelf (6x Pi 5)
1U - Storage/expansion
1U - Cooling and monitoring
```

**Shock Mounting**:
- Spring-loaded rack rails
- Vibration dampening mounts
- Component retention straps
- Anti-vibration washers

### Vehicle Integration

**Mounting Locations**:

1. **Center Console** (small 3-node):
   - Easy access
   - Climate controlled
   - Minimal wiring
   - May interfere with seats

2. **Rear Equipment Area**:
   - Dedicated space
   - Professional installation
   - Better cooling
   - Requires AC extension or ventilation

3. **Under-seat**:
   - Space-efficient
   - Protected location
   - Limited cooling
   - Difficult service access

**Mounting Hardware**:
- Quick-release brackets
- Ratchet straps with padding
- L-track mounting points
- Anti-slip matting

## Environmental Protection

### Temperature Management

**Operating Range**: -20°C to +60°C

**Cooling System**:

```bash
# Temperature-controlled fans
sudo apt install fancontrol

# Configure thresholds
sudo nano /etc/fancontrol
```

Example configuration:

```ini
INTERVAL=5
DEVPATH=hwmon0
DEVNAME=cpu_thermal
FCTEMPS=hwmon0/pwm1=hwmon0/temp1_input
FCFANS=hwmon0/pwm1=hwmon0/fan1_input
MINTEMP=40
MAXTEMP=70
MINSTART=50
MINSTOP=30
```

**Heating (cold climates)**:
- Insulated enclosure
- Waste heat from components (usually sufficient)
- 12V silicone heating pad (if needed)
- Temperature monitoring and alerts

### Dust and Moisture

**Protection Level**: IP54 minimum (IP65 preferred)

**Sealing**:
- Gasket-sealed enclosure
- Cable glands for all penetrations
- Desiccant packs inside
- Breather vents (IP65 rated)

**Filtration**:
- Intake fan filters (replaceable)
- Fine mesh (50-100 micron)
- Regular maintenance schedule

### Shock and Vibration

**Isolation Methods**:

1. **Component Level**:
   - Silicone standoffs for Pi boards
   - Thermal pads (dual purpose: cooling + dampening)
   - Secure all connectors

2. **Enclosure Level**:
   - Spring-mounted rack rails
   - Rubber shock mounts
   - Foam padding around components

3. **Vehicle Level**:
   - Secure mounting points
   - Minimize cantilever loads
   - Regular inspection of fasteners

## Monitoring and Management

### Remote Monitoring

**Metrics to Track**:
- Power consumption and battery state
- CPU temperature (all nodes)
- Network connectivity and signal strength
- GPS location
- System health (K3s cluster status)

**Tools**:

```bash
# Install monitoring stack
kubectl apply -f monitoring/prometheus.yaml
kubectl apply -f monitoring/grafana.yaml

# Add vehicle-specific dashboards
# - Power metrics
# - Temperature monitoring
# - Network quality
# - GPS tracking
```

### Alerting

**Critical Alerts**:
- Battery low (< 30%)
- Temperature high (> 75°C)
- Network loss (> 5 minutes)
- Node down
- Storage full (> 85%)

**Notification Methods**:
- SMS (via cellular)
- Email (when connected)
- Local alarm (buzzer/LED)
- Remote dashboard

## Deployment Procedures

### Pre-Deployment Checklist

```text
[ ] Battery fully charged (> 95%)
[ ] All nodes booting correctly
[ ] Network connectivity tested
[ ] Antennas properly mounted
[ ] Cooling system operational
[ ] Backup connectivity verified
[ ] GPS sync confirmed
[ ] Service health checks passed
[ ] Equipment secured in vehicle
[ ] Emergency contacts updated
```

### Rapid Setup

**Goal**: Operational in < 15 minutes

```text
T+0:00  Vehicle arrives at location
T+0:02  Position vehicle, engage parking brake
T+0:03  Deploy antennas (if external)
T+0:05  Power on system (automatic boot)
T+0:08  Deploy solar panels (if using)
T+0:10  System health check
T+0:12  Network connectivity verified
T+0:15  Services available, operational
```

### Teardown Procedure

```text
1. Notify users of shutdown (15 min warning)
2. Graceful service shutdown
3. K3s cluster drain and cordon
4. Power down nodes
5. Secure antennas
6. Stow solar panels
7. Check all fasteners
8. Document location and duration
```

## Bill of Materials

### Complete Mobile Setup (6-node)

**Compute**:
```text
6x Raspberry Pi 5 (8GB)              $480
6x Samsung 512GB NVMe SSD            $300
6x GeeekPi N05 PCIe adapter          $60
6x Waveshare PoE HAT or USB-C PD     $210
Subtotal:                            $1,050
```

**Power**:
```text
LiFePO4 Battery (12V 200Ah)          $1,000
Mean Well DC-DC Converter            $40
Renogy DC-DC Charger (30A)           $200
Victron MPPT Solar Controller        $250
2x 200W Solar Panels                 $400
USB-C PD Trigger Boards (6x)         $30
DC Distribution Board                $50
Wiring and connectors                $100
Subtotal:                            $2,070
```

**Networking**:
```text
Peplink MAX Transit Duo              $1,200
Cellular antennas (MIMO pair)        $150
Ubiquiti WiFi AP                     $180
Network switch (8-port PoE)          $150
Subtotal:                            $1,680
```

**Enclosure**:
```text
6U Shock-mount rack case             $400
Cooling fans and filters             $80
Cable management                     $50
Mounting hardware                    $100
Subtotal:                            $630
```

**Optional**:
```text
Starlink Mobile (dish + router)      $2,500
GPS module                           $60
Temperature sensors                  $40
UPS monitoring                       $80
LoRa gateway                         $150
Subtotal:                            $2,830
```

**Total Base System**: ~$5,430  
**With All Options**: ~$8,260

## Maintenance

### Daily Checks

```bash
#!/bin/bash
# daily-check.sh

# Battery voltage
vcgencmd get_throttled

# Temperature
vcgencmd measure_temp

# Network signal
# (specific to router model)

# Disk space
df -h

# Service health
kubectl get nodes
kubectl get pods -A
```

### Weekly Maintenance

- Clean air filters
- Check all fasteners
- Verify battery voltage
- Test backup connectivity
- Review logs for errors

### Monthly Maintenance

- Deep clean enclosure
- Inspect all cables
- Update system packages
- Test failover scenarios
- Battery health check

## Troubleshooting

### No Network Connectivity

```bash
# Check cellular signal
# Router-specific commands

# Verify WAN interface
ip route show

# Test DNS
nslookup google.com

# Try backup connection (if available)
```

### Overheating in Vehicle

```bash
# Check temperatures
vcgencmd measure_temp

# Verify fans running
# Physical inspection

# Reduce load temporarily
kubectl scale deployment --replicas=1

# Improve ventilation
# Open windows, run vehicle AC
```

### Battery Drain Faster Than Expected

```bash
# Check power consumption
# Use USB power meter

# Identify high-load pods
kubectl top pods -A

# Enable power saving
sudo cpufreq-set -g powersave
```

### Vibration Damage

**Symptoms**: Loose connections, intermittent failures

**Prevention**:
- Use threadlocker on screws
- Cable strain relief
- Regular inspections
- Better shock mounting

## Next Steps

1. [Hardware Requirements](./hardware.md) - Component selection
2. [EEPROM Configuration](./eeprom-configuration.md) - Boot setup
3. [Initial Setup](./initial-setup.md) - System configuration
4. [Deploy K3s](../guides/deploy.md) - Cluster installation

## References

- [Vehicle Integration Best Practices](https://www.adventure-rv.net/12v-power-systems)
- [LiFePO4 Battery Guide](https://battlebornbatteries.com/blog/)
- [Cellular Antenna Placement](https://www.digi.com/resources/documentation/digidocs/90002258/Default.htm)
- [Mobile Network Design](https://www.peplink.com/solutions/mobile-command/)
