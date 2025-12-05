# arclink - OpenTAKServer on K3s

**Complete automation for deploying OpenTAKServer on Kubernetes clusters with Ansible.** Production-tested on Raspberry Pi 5 clusters, works on any ARM64/AMD64 hardware.

[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://jcayouette.github.io/arclink/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 🎯 What is Arclink?

Arclink provides **complete infrastructure automation** for running OpenTAKServer on K3s clusters:

- 🤖 **Full Automation** - Bare metal to running application in ~45 minutes
- 🏗️ **High Availability** - 3+ master nodes with embedded etcd
- 🔧 **Socket.IO Patches** - WebSocket support for real-time updates
- 📦 **Everything Included** - K3s, Longhorn, Registry, PostgreSQL, RabbitMQ
- 🔄 **Production Ready** - Tested on 7-node Raspberry Pi 5 cluster
- 📚 **Comprehensive Docs** - Step-by-step guides for every scenario

## 🚀 Quick Start with Ansible (Recommended)

### Prerequisites
- Ubuntu Server 24.04 LTS on cluster nodes
- Ansible 2.9+ on your workstation/WSL
- SSH access to nodes

### Deploy Everything

```bash
# 1. Install Ansible and clone repo
sudo apt install -y ansible
git clone https://github.com/jcayouette/arclink.git
cd arclink/ansible

# 2. Configure your cluster
vim inventory/production.yml  # Add your nodes

# 3. Deploy infrastructure (one-time setup)
ansible-playbook playbooks/bootstrap.yml --ask-pass
ansible-playbook playbooks/setup-common.yml
ansible-playbook playbooks/deploy-k3s.yml
ansible-playbook playbooks/deploy-rancher.yml  # Optional: Management UI
ansible-playbook playbooks/mount-longhorn-disks.yml  # First time only: Mount NVMe partitions
ansible-playbook playbooks/deploy-longhorn.yml  # Required: Distributed storage
ansible-playbook playbooks/deploy-registry.yml

# 4. Deploy OpenTAKServer with Socket.IO patches
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

**Time:** ~45 minutes first run (including image build), ~15 minutes for redeployment

**Access:** `http://node0:31080` (default credentials: administrator/password)

## 📚 Documentation

**🌟 [Complete Documentation Site](https://jcayouette.github.io/arclink/)**

### Quick Links
- **[Quick Start Guide](https://jcayouette.github.io/arclink/docs/guides/quickstart)** - Get running fast
- **[Complete Deployment Guide](https://jcayouette.github.io/arclink/docs/guides/complete-deployment)** - Step-by-step walkthrough
- **[Ansible Overview](https://jcayouette.github.io/arclink/docs/guides/ansible/overview)** - Full automation details
- **[Playbooks Reference](https://jcayouette.github.io/arclink/docs/guides/ansible/playbooks-reference)** - All 15 playbooks documented

### In This Repo
- **[ansible/README.md](ansible/README.md)** - Complete Ansible guide
- **[CLEANUP-AND-HA-ROADMAP.md](CLEANUP-AND-HA-ROADMAP.md)** - Future enhancements roadmap
- **[CHANGES.md](CHANGES.md)** - Detailed changelog

## ✨ What's Automated

### Infrastructure (Ansible)
✅ **System Preparation** - Kernel modules, sysctl, packages  
✅ **K3s Cluster** - HA deployment with embedded etcd  
✅ **Rancher UI** - Optional web management interface  
✅ **Longhorn Storage** - Auto-mount large partitions (~1.5TB total), distributed block storage  
✅ **Docker Registry** - Local registry for custom images  
✅ **Validation** - Pre-flight and post-deployment checks  
✅ **Auto-Fixes** - Stuck replicasets, missing CSI plugins  

### Application (Ansible)
✅ **Image Building** - OpenTAKServer with Socket.IO patches  
✅ **PostgreSQL** - Database with persistent storage  
✅ **RabbitMQ** - Message queue for async tasks  
✅ **OpenTAKServer** - Main application with WebSocket support  
✅ **Nginx** - Reverse proxy with WebSocket forwarding  

### Management
✅ **Cluster Reset** - Complete teardown and cleanup  
✅ **Cluster Restart** - Service restart automation  
✅ **Node Addition** - Scale cluster up or down  
✅ **Updates** - Rolling updates with minimal downtime  
✅ **Storage Management** - Wipe/redeploy Longhorn with automation  
✅ **Real-time Monitoring** - Dashboard for Longhorn deployment status  

## 🏗️ Architecture

**Tested Configuration:**
- 7-node Raspberry Pi 5 cluster (8GB RAM each)
- 3 master nodes (HA with embedded etcd)
- 4 agent nodes (workload distribution)
- Ubuntu Server 24.04 LTS
- K3s v1.33.6+k3s1 with Longhorn v1.7.2
- 1,513 GB total storage (409GB node0, 184GB × 6 nodes)
- NVMe SSDs: 500GB (node0), 250GB (nodes 1-6)

**Supported Cluster Sizes:**
- **Single node** - Development/testing
- **3 nodes** - Minimum HA (recommended for production)
- **7+ nodes** - Large deployments with better distribution

## 🔧 Key Features

### Automated Storage Management
- **Auto-mount large partitions** - Detects and configures ~1.5TB across cluster
- **Longhorn integration** - Uses `/mnt/longhorn` for persistent storage
- **Smart disk configuration** - Disables default disk, uses dedicated partitions
- **Wipe/redeploy automation** - Clean storage cleanup and redeployment

### High Availability
- **3+ master nodes** - Embedded etcd for control plane HA
- **Distributed storage** - Longhorn with 3 replicas
- **Load distribution** - Workloads across agent nodes
- **Automatic failover** - Built-in K3s and Longhorn resilience

### Smart Deployment
- **Auto-fixes** - Detects and resolves stuck replicasets, missing CSI plugins
- **Real-time monitoring** - Live dashboard during deployments
- **Progress tracking** - Detailed status for each deployment phase
- **Pre-flight checks** - Validates prerequisites before deployment

**📖 Complete Guides:** [CHANGES.md](CHANGES.md) | **📚 Documentation:** [https://jcayouette.github.io/arclink/](https://jcayouette.github.io/arclink/)

## Documentation

The project documentation is built with Docusaurus and deployed to GitHub Pages. To work with the documentation locally:

```bash
cd docs
npm start        # Start local dev server at http://localhost:3000
npm run build    # Build static site
```

Documentation is automatically deployed to GitHub Pages when changes are pushed to the `docs/` directory.

## 🌐 Services

- **OpenTAK Web UI:** `http://<node-address>:31080` (default: administrator/password)
- **Longhorn UI:** `http://<node-address>:30630` (storage management)
- **Rancher UI:** `https://rancher.<your-domain>` (optional, cluster management)
- **TCP CoT:** `<node-address>:31088`
- **SSL CoT:** `<node-address>:31089`

## 🛠️ Management & Monitoring

### Ansible Playbooks
```bash
ansible-playbook playbooks/validate-k3s-cluster.yml   # Health check
ansible-playbook playbooks/wipe-longhorn-disks.yml    # Clean Longhorn storage
ansible-playbook playbooks/reset-cluster.yml          # Full cluster reset
```

### Helper Scripts
```bash
./scripts/helpers/monitor-longhorn.sh      # Real-time Longhorn dashboard
./scripts/helpers/stream-longhorn-logs.sh  # Live log streaming
./scripts/helpers/status.sh                # Check deployment status
./scripts/helpers/logs.sh                  # View application logs
./scripts/helpers/set-admin-password.sh    # Reset admin password
```

**See [ansible/README.md](ansible/README.md) for complete playbook documentation**

## 🔍 Troubleshooting

Common issues and solutions:
- **Longhorn showing low storage**: Run `ansible-playbook playbooks/mount-longhorn-disks.yml`
- **Longhorn pods crash-looping**: Redeploy with auto-fixes: `ansible-playbook playbooks/deploy-longhorn.yml`
- **Stuck deployments (0/X replicas)**: Auto-fixed by deploy-longhorn.yml playbook
- **ImagePullBackOff errors**: See [Troubleshooting Guide](docs/docs/guides/troubleshooting.md)
- **Pod not starting**: Check logs with `./scripts/helpers/logs.sh` or `kubectl logs`

**📖 Full troubleshooting guide:** [docs/docs/guides/troubleshooting.md](docs/docs/guides/troubleshooting.md)

## ✨ Features

- **Portable configuration** - Works on any ARM64/AMD64 hardware
- **Automated storage** - 1.5TB distributed storage auto-configured
- **Fast deployment** - ~10 seconds pod startup with pre-built images
- **Socket.IO patches** - WebSocket support with CORS and optimized timeouts
- **High availability** - Multi-master K3s with Longhorn replication
- **Smart auto-fixes** - Detects and resolves common deployment issues
- **Real-time monitoring** - Live dashboards during deployments
- **Multi-architecture** - Tested on Raspberry Pi 5 and x86_64

## License

This deployment configuration is MIT licensed. OpenTAKServer itself is licensed separately.
