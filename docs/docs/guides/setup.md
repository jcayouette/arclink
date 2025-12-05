---
sidebar_position: 2
---

# Manual Setup (Alternative Method)

:::tip Recommended Approach
For automated deployment, see the **[Quick Start Guide](./quickstart.md)** or **[Complete Deployment Guide](./complete-deployment.md)** which use Ansible for full automation from bare metal to running application.
:::

This guide covers the **manual setup approach** using shell scripts. Use this method if you:
- Prefer step-by-step manual control
- Already have a K3s cluster running
- Want to understand the deployment process in detail
- Need to customize beyond Ansible automation

## Prerequisites

Ensure you have completed:
- ✅ K3s cluster is running (`sudo systemctl status k3s`)
- ✅ Docker installed and accessible
- ✅ Network connectivity to primary node (if multi-node)
- ✅ SSH keys configured (multi-node clusters only)

### Multi-Node Cluster Setup

For multi-node deployments, configure SSH keys for passwordless authentication:

```bash
./scripts/helpers/setup-ssh-keys.sh
```

This enables:
- Automated registry configuration distribution
- Seamless cluster management
- Passwordless node access for deployment scripts

**Why it's needed:** Agent nodes require the insecure registry configuration to pull images from the local Docker registry. The setup and redeploy scripts automatically distribute this configuration using SSH.

## Comparison: Ansible vs Manual Scripts

| Feature | Ansible (Recommended) | Manual Scripts |
|---------|----------------------|----------------|
| **Deployment** | Bare metal to app | Requires K3s pre-installed |
| **Time** | ~45 min (first run) | ~30 min (building images) |
| **Automation** | Full lifecycle | Build and deploy only |
| **System Prep** | Automated | Manual |
| **K3s Install** | Automated (with HA) | Manual pre-requisite |
| **Validation** | Pre/post checks | Manual verification |
| **Best For** | Production, fresh clusters | Existing K3s, customization |

:::info When to Use Manual Scripts
- You already have K3s installed and configured
- You want fine-grained control over each step
- You're troubleshooting specific components
- You need to customize beyond Ansible's scope
:::

## Setup Process Overview

The setup consists of three main phases:

1. **Docker Registry Setup** - Local registry for image distribution
2. **Image Building** - Custom OpenTAK Server and UI images
3. **Registry Push** - Upload images for K3s access

## Phase 1: Docker Registry Setup

### Automated Registry Setup

The easiest approach is to run the configuration script which handles everything:

```bash
./scripts/configure.sh
```

This automatically:
1. Starts Docker registry container on port 5000
2. Configures K3s to trust the insecure registry
3. Updates `/etc/rancher/k3s/registries.yaml`
4. Restarts K3s service

### Manual Registry Setup

If you need to set up the registry manually or troubleshoot:

**Start the registry container:**
```bash
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /var/lib/registry:/var/lib/registry \
  registry:2
```

**Configure K3s insecure registry (required!):**
```bash
# Create or edit K3s registry config
sudo mkdir -p /etc/rancher/k3s
sudo nano /etc/rancher/k3s/registries.yaml
```

Add your registry configuration:
```yaml
mirrors:
  "192.168.1.100:5000":  # Replace with your REGISTRY_ADDRESS
    endpoint:
      - "http://192.168.1.100:5000"
```

**Restart K3s to apply changes:**
```bash
sudo systemctl restart k3s
```

**For multi-node clusters**, repeat registry configuration on ALL nodes.

### Verify Registry

```bash
# Check registry is running
docker ps | grep registry

# Test registry API
curl http://localhost:5000/v2/_catalog

# Should return: {"repositories":[]}
```

## Phase 2: Image Building

### Automated Build

The build script handles everything:

```bash
cd docker
./setup.sh
```

**Build time:** ~30 minutes first time (cached afterwards)

### What Gets Built

The setup builds two custom images with pre-installed dependencies for fast pod startup:

**OpenTAK Server Image** (`docker/opentakserver/Dockerfile`)
- **Base**: Python 3.13
- **Source**: OpenTAK Server from GitHub (brian7704/OpenTAKServer)
- **Patches**: Socket.IO fixes for CORS and session compatibility
- **Dependencies**: All Python packages pre-installed
- **Port**: 8081 (Flask API)
- **Purpose**: Main TAK server application

**UI Image** (`docker/ui/Dockerfile`)
- **Build Stage**: Node.js (builds React/TypeScript UI)
- **Runtime**: Nginx  
- **Content**: Pre-built static assets from brian7704/OpenTAKServer-UI
- **Port**: 8080 (serves UI, proxies API)
- **Purpose**: Web interface and reverse proxy

### Why Custom Images?

- **Fast Startup**: Pods start in ~10 seconds vs 10-15 minutes with init containers
- **Reliability**: No network dependency during pod startup
- **Version Control**: Pin specific OpenTAK Server versions
- **Offline Capability**: Can restart pods without internet
- **Pre-patched**: Socket.IO fixes already applied

### Manual Build Process

If you need to build images step-by-step:

**Build OpenTAK Server:**
```bash
cd docker/opentakserver
docker build -t localhost:5000/opentakserver:latest .
```

**Build UI:**
```bash
cd docker/ui
docker build -t localhost:5000/opentakserver-ui:latest .
```

## Phase 3: Push Images to Registry

After building, push images to make them accessible to K3s:

```bash
# Push OpenTAK Server image
docker push localhost:5000/opentakserver:latest

# Push UI image  
docker push localhost:5000/opentakserver-ui:latest
```

**The `setup.sh` script does this automatically.**

### Update Manifests

After building images, update manifests to reference your registry:

```bash
# Update image references in YAML files
sed -i "s|REGISTRY_ADDRESS|${REGISTRY_ADDRESS}|g" manifests/ots-with-ui-custom-images.yaml
```

**This is handled automatically by `configure.sh`.**

## Manual Build Process

If you need to build images manually:

### Build OpenTAK Server

```bash
cd docker/opentakserver
docker build -t localhost:5000/opentakserver:latest .
docker push localhost:5000/opentakserver:latest
```

### Build UI

```bash
cd docker/ui
docker build -t localhost:5000/opentakserver-ui:latest .
docker push localhost:5000/opentakserver-ui:latest
```

## Customizing Images

### OpenTAK Server Version

To build a specific version:

```dockerfile
# In docker/opentakserver/Dockerfile
RUN pip install git+https://github.com/brian7704/OpenTAKServer.git@v1.2.3
```

### Adding Custom Dependencies

Edit the Dockerfile to add packages:

```dockerfile
RUN apt update && apt install -y \
    your-package \
    another-package
```

### Environment Variables

Add custom environment variables:

```dockerfile
ENV YOUR_VAR=value
ENV ANOTHER_VAR=value
```

## Multi-Architecture Builds

### Building for ARM64 (Raspberry Pi)

On an ARM64 device:
```bash
./setup.sh
```

### Building for AMD64 (x86_64)

On an x86_64 device:
```bash
./setup.sh
```

### Cross-Platform Builds

Using Docker Buildx:

```bash
# Setup buildx
docker buildx create --name multiarch --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5000/opentakserver:latest \
  --push \
  docker/opentakserver
```

## Verifying Setup

### Check Local Images

```bash
docker images | grep localhost:5000
```

**Expected output:**
```text
localhost:5000/opentakserver        latest    abc123...   30 minutes ago   1.2GB
localhost:5000/opentakserver-ui     latest    def456...   25 minutes ago   50MB
```

### Check Registry Contents

```bash
curl http://localhost:5000/v2/_catalog
```

**Expected output:**
```json
{
  "repositories": [
    "opentakserver",
    "opentakserver-ui"
  ]
}
```

### Test Image Pull from Registry

```bash
# Pull image from registry as K3s would
docker pull localhost:5000/opentakserver:latest
docker pull localhost:5000/opentakserver-ui:latest
```

Should complete successfully without errors.

### Verify K3s Registry Configuration

```bash
# Check K3s registry config
cat /etc/rancher/k3s/registries.yaml

# Should show your registry address
```

**Expected content:**
```yaml
mirrors:
  "192.168.1.100:5000":
    endpoint:
      - "http://192.168.1.100:5000"
```

### Test from Worker Node (Multi-Node Only)

On each worker node:
```bash
# Test registry connectivity
curl http://192.168.1.100:5000/v2/_catalog

# Try pulling image
docker pull 192.168.1.100:5000/opentakserver:latest
```

3. **Registry Push**
   - Pushes to local registry
   - Verifies upload
   - Reports status

## Customizing Images

### Building Specific OpenTAK Server Version

To use a specific version instead of latest:

```dockerfile
# In docker/opentakserver/Dockerfile, change this line:
RUN pip install git+https://github.com/brian7704/OpenTAKServer.git@v1.2.3
```

Then rebuild:
```bash
cd docker/opentakserver
docker build -t localhost:5000/opentakserver:v1.2.3 .
docker push localhost:5000/opentakserver:v1.2.3
```

Update manifest to use this version:
```yaml
image: 192.168.1.100:5000/opentakserver:v1.2.3
```

### Adding Custom Dependencies

To install additional packages:

```dockerfile
# In docker/opentakserver/Dockerfile, add after apt install section:
RUN apt update && apt install -y \
    your-package \
    another-package
```

### Custom Patches

If you need to apply additional patches to OpenTAK Server:

```dockerfile
# After pip install, before COPY patches
COPY your-patch.patch /opt/opentakserver/
RUN cd /opt/opentakserver && patch -p1 < your-patch.patch
```

## Multi-Architecture Builds

### Native Build (Recommended)

Build on the target architecture:
- **Raspberry Pi**: Build on a Pi (ARM64)
- **x86_64 Server**: Build on the server (AMD64)

```bash
# Build natively on target hardware
cd docker
./setup.sh
```

### Cross-Platform with Buildx (Advanced)

Build for multiple architectures from one machine:

```bash
# Setup buildx (one-time)
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Build for both ARM64 and AMD64
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5000/opentakserver:latest \
  --push \
  docker/opentakserver

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5000/opentakserver-ui:latest \
  --push \
  docker/ui
```

:::info
Cross-compilation is slower than native builds. Use native builds when possible.
:::

## Troubleshooting Setup

### Issue: Registry Container Won't Start

**Symptoms**: `docker run registry` fails or exits immediately

**Solution**: Check port 5000 isn't already in use
```bash
# Check what's using port 5000
sudo lsof -i :5000

# Stop conflicting service or use different port
docker run -d -p 5001:5000 --name registry registry:2
```

### Issue: K3s Can't Pull Images

**Symptoms**: Pods stuck in `ImagePullBackOff` or `ErrImagePull`

**Solution 1**: Verify registry configuration
```bash
# Check K3s registry config
cat /etc/rancher/k3s/registries.yaml

# Should list your registry with http:// endpoint
```

**Solution 2**: Restart K3s after registry config changes
```bash
sudo systemctl restart k3s

# Wait for K3s to be ready
sudo kubectl get nodes
```

**Solution 3**: Test registry connectivity from K3s pod
```bash
# Run test pod
kubectl run test --image=busybox -it --rm -- sh

# Inside pod, test registry
wget -O- http://192.168.1.100:5000/v2/_catalog
```

### Issue: Docker Build Fails - Network Timeout

**Symptoms**: `pip install` or `npm install` times out during build

**Solution**: Check internet connectivity, retry with longer timeout
```bash
# Increase build timeout
docker build --network=host \
  -t localhost:5000/opentakserver:latest \
  docker/opentakserver
```

### Issue: Out of Disk Space During Build

**Symptoms**: "no space left on device" error

**Solution**: Clean up Docker resources
```bash
# Remove unused images and containers
docker system prune -a

# Check disk usage
df -h
docker system df

# If needed, expand disk or move Docker data dir
```

### Issue: Push to Registry Fails

**Symptoms**: `error pushing image` or `connection refused`

**Solution**: Verify registry is running and accessible
```bash
# Check registry status
docker ps | grep registry

# Test registry API
curl http://localhost:5000/v2/

# Should return: {}

# If using remote registry, test from build machine
curl http://192.168.1.100:5000/v2/
```

### Issue: Multi-Node - Workers Can't Access Registry

**Symptoms**: Workers show `ImagePullBackOff`, primary node works fine

**Solution**: Configure registry on ALL nodes
```bash
# On each worker node
sudo nano /etc/rancher/k3s/registries.yaml

# Add registry config (use primary node IP)
mirrors:
  "192.168.1.100:5000":
    endpoint:
      - "http://192.168.1.100:5000"

# Restart K3s on worker
sudo systemctl restart k3s
```

## Performance Tips

### Speed Up Builds

**Use Build Cache** (default behavior):
```bash
# Subsequent builds use cache (~2 minutes vs 30 minutes)
cd docker && ./setup.sh
```

**Force Fresh Build** (when needed):
```bash
docker build --no-cache \
  -t localhost:5000/opentakserver:latest \
  docker/opentakserver
```

**Parallel Builds** (if you have multiple cores):
```bash
# Build both images simultaneously
docker build -t localhost:5000/opentakserver:latest docker/opentakserver &
docker build -t localhost:5000/opentakserver-ui:latest docker/ui &
wait
```

### Optimize Image Size

The images are already optimized, but for custom builds:
- Use multi-stage builds (already implemented in UI)
- Clean up package caches in same RUN command
- Remove unnecessary development dependencies

## Next Steps

After completing setup, you're ready to:
1. **[Deploy to K3s](./deploy.md)** - Launch your OpenTAK Server
2. **Verify deployment** - Check pods are running
3. **Set admin password** - Secure your installation

## Next Steps

After successful setup:
- [Deploy to K3s](./deploy.md)
- [Verify deployment status](./deploy.md#verifying-deployment)

## Alternative: Pre-built Images

For faster deployment, pre-built images can be used (future feature):

```yaml
# In manifests
image: ghcr.io/jcayouette/arclink-opentakserver:latest
```

This eliminates the build step but requires internet connectivity.
