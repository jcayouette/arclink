---
sidebar_position: 2
---

# Release Notes

Track changes, improvements, and updates to Arclink.

## Latest Changes

### December 4, 2025 - Complete Ansible Automation & Documentation Overhaul

**Ansible Automation (Fully Implemented)**
- ✅ Complete automation from bare metal to running application
- ✅ 15 production-ready playbooks for full lifecycle management
- ✅ 5 roles: common, k3s-master, k3s-agent, docker-registry, docker-build
- ✅ High Availability support (3+ master nodes with embedded etcd)
- ✅ Automated SSH key distribution with bootstrap playbook
- ✅ System preparation (kernel modules, sysctl, packages)
- ✅ K3s cluster deployment with HA detection
- ✅ Longhorn distributed storage deployment
- ✅ Local Docker registry setup and configuration
- ✅ OpenTAKServer deployment with Socket.IO patches
- ✅ Cluster reset and restart capabilities
- ✅ Pre-flight and post-deployment validation
- ✅ Rancher UI deployment (optional)

**Socket.IO Fixes**
- ✅ Auto-detection of Python version (3.11, 3.12, 3.13)
- ✅ CORS headers enabled: `cors_allowed_origins='*'`
- ✅ RabbitMQ message_queue removed
- ✅ Ping timeout increased to 60 seconds
- ✅ Patches applied during image build
- ✅ Verification in running containers
- ✅ WebSocket connections now work properly (HTTP 200, not 400)

**Docker Build Optimization**
- ✅ Docker layer caching for fast rebuilds
- ✅ First build: ~30 minutes
- ✅ Subsequent builds: ~3-5 minutes
- ✅ Automated push to local registry
- ✅ Multi-node image distribution

**Documentation Site**
- ✅ Comprehensive Quick Start guide (both Ansible and manual)
- ✅ Complete Deployment guide with step-by-step walkthrough
- ✅ Ansible automation overview and reference
- ✅ Playbooks reference documentation (all 15 playbooks)
- ✅ Getting Started guide for new deployments
- ✅ Progress checklist (all phases marked complete)
- ✅ High Availability configuration guide
- ✅ Troubleshooting guides for each step
- ✅ Hardware requirements and cluster sizing
- ✅ Common workflows: update, reset, add/remove nodes

**Testing & Validation**
- ✅ Tested on 7-node Raspberry Pi 5 cluster (3 masters + 4 agents)
- ✅ Ubuntu Server 24.04 LTS compatibility verified
- ✅ HA with embedded etcd operational
- ✅ Automated validation playbooks
- ✅ All system pods running and healthy
- ✅ Longhorn storage with 3-replica redundancy
- ✅ Registry accessible from all nodes
- ✅ OpenTAKServer with working WebSocket support

### December 3, 2025 - Ansible Implementation

**Added**
- Initial Ansible playbook structure
- Inventory configuration for production clusters
- Common role for system preparation
- K3s master and agent roles
- Docker registry role
- Bootstrap playbook for SSH automation

### December 2025 - Initial Release

**Added**
- Initial public release of Arclink
- Complete K3s deployment automation for OpenTAK Server
- Support for both Longhorn and local-path-provisioner storage
- Automated configuration script with secret generation
- Multi-architecture support (ARM64/AMD64)
- Documentation site with Docusaurus

**Infrastructure**
- Production-ready Kubernetes manifests
- Docker registry integration
- Persistent PostgreSQL storage
- RabbitMQ message queue
- Nginx ingress controller

**Documentation**
- Installation guides
- Architecture overview
- Raspberry Pi 5 deployment guide
- K3s setup instructions

## Planned Features

### Near Term (Q1 2025)

- [x] ~~High availability with multi-node clusters~~ **COMPLETED** ✅
- [ ] MetalLB load balancer integration
- [ ] Automated backup and restore procedures
- [ ] Monitoring with Prometheus/Grafana stack
- [ ] Resource limit optimization and tuning
- [ ] Certificate management automation
- [ ] Redis for session management (multi-replica HA)

### Future Enhancements

- [ ] Helm chart packaging for easier deployment
- [ ] Air-gapped deployment support
- [ ] Custom resource definitions (CRDs)
- [ ] Automated upgrades and rollbacks
- [ ] Edge-to-cloud synchronization
- [ ] Enhanced security hardening (RBAC, network policies)
- [ ] Multi-cluster federation
- [ ] Automated scaling based on load

## Version History

### v0.2.0 (December 4, 2025)

Major update with complete Ansible automation and comprehensive documentation.

**Core Features**
- Complete automation: bare metal to running application in ~45 minutes
- 15 production-ready Ansible playbooks
- 5 reusable roles for infrastructure components
- High Availability support with embedded etcd
- Socket.IO patches for WebSocket functionality
- Docker build optimization with layer caching
- Comprehensive documentation with guides and troubleshooting

**Automation Improvements**
- SSH key distribution automation
- Parallel execution across all nodes
- Automated validation (pre-flight and post-deployment)
- One-command deployment workflows
- Cluster reset and restart capabilities
- Add/remove node support

**Supported Platforms**
- Raspberry Pi 5 (ARM64) - Tested on 7-node cluster
- x86_64 Linux servers
- K3s 1.28+ with embedded etcd
- Ubuntu Server 24.04 LTS

**Cluster Sizes**
- Single node (development/testing)
- 3-node HA (minimum for production)
- 7+ node clusters (tested and validated)

---

### v0.1.0 (December 2025)

First public release of Arclink deployment automation for OpenTAK Server on K3s.

**Core Features**
- Single-command deployment
- Automatic secret generation
- Persistent storage configuration
- Multi-architecture container builds
- Portable configuration system

**Supported Platforms**
- Raspberry Pi 5 (ARM64)
- x86_64 Linux servers
- K3s 1.28+

---

For detailed changes, see the [CHANGES.md](https://github.com/jcayouette/arclink/blob/main/CHANGES.md) file in the repository.
