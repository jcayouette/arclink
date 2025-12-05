# OpenTAKServer Custom Docker Images

This directory contains Dockerfiles for building stable, production-ready OpenTAKServer images optimized for ARM64 (Raspberry Pi 5).

## Why Custom Images?

The original deployment used init containers that:
- Clone and build the UI on every pod restart (~5 minutes)
- Install system packages (ffmpeg, curl) on every restart (~2-3 minutes)
- Install Python packages on every restart (~3-5 minutes)
- Pull "latest" versions causing potential instability

Custom images solve this by:
- Pre-building everything at a specific version
- Fast pod restarts (seconds instead of minutes)
- Consistent, reproducible deployments
- Version pinning for stability
- No network dependency during pod startup

## Building Images

### Prerequisites

You can build on any node with Docker installed. For Raspberry Pi:

```bash
# If Docker isn't installed
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### Option 1: Local Registry (Recommended for k3s)

K3s can pull from a local registry running on your network:

```bash
# Set up a local registry (on node0 or any accessible node)
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Build and push to local registry
export REGISTRY=node0:5000  # Use your node's hostname or IP
./docker/build.sh

# Push images
docker push node0:5000/opentakserver:latest
docker push node0:5000/opentakserver-ui:latest
```

### Option 2: Import Directly to k3s (No Registry)

Build on any Pi node and import directly:

```bash
# Build images
export REGISTRY=local
./docker/build.sh

# Import into k3s containerd
docker save local/opentakserver:latest | sudo k3s ctr images import -
docker save local/opentakserver-ui:latest | sudo k3s ctr images import -

# Verify images are available
sudo k3s ctr images ls | grep opentakserver
```

### Option 3: External Registry (DockerHub, GitHub, etc.)

```bash
# Login to your registry
docker login

# Build with your registry
export REGISTRY=your-dockerhub-username
./docker/build.sh

# Push images
docker push your-dockerhub-username/opentakserver:latest
docker push your-dockerhub-username/opentakserver-ui:latest
```

## Version Management

Pin specific versions for stability:

```bash
# Build specific versions
export OTS_VERSION=1.6.3
export UI_VERSION=main  # or specific commit/tag
./docker/build.sh
```

Update the version in the Dockerfile and rebuild when you want to upgrade.

## Using Custom Images

After building and pushing/importing images, update `manifests/ots-with-ui.yaml`:

```yaml
# Replace init containers with:
initContainers:
- name: setup-config
  image: busybox
  command: ["/bin/sh", "-c"]
  args:
    - |
      cat > /home/ots/ots/config.yml << 'EOFCONFIG'
      SQLALCHEMY_DATABASE_URI: postgresql+psycopg://ots:otspassword@postgres:5432/ots
      # ... rest of config
      EOFCONFIG
  volumeMounts:
  - name: ots-data
    mountPath: /home/ots/ots

# Replace main containers with:
containers:
- name: ots
  image: node0:5000/opentakserver:latest  # Use your registry
  volumeMounts:
  - name: ots-data
    mountPath: /home/ots/ots

- name: nginx
  image: node0:5000/opentakserver-ui:latest  # Use your registry
  ports:
  - containerPort: 8080
  volumeMounts:
  - name: nginx-config
    mountPath: /etc/nginx/nginx.conf
    subPath: nginx.conf
```

## Build Times

Building from scratch on Raspberry Pi 5:
- OpenTAKServer image: ~15-20 minutes
- UI image: ~10-15 minutes
- Total: ~30 minutes one-time build

Pod startup after using custom images:
- With custom images: ~5-10 seconds
- Without (current): ~10-15 minutes

## Updating Images

When you want to upgrade:

1. Update version in build script or Dockerfile
2. Rebuild: `./docker/build.sh`
3. Push/import to registry
4. Update deployment: `kubectl apply -f manifests/ots-with-ui.yaml`
5. Restart pods: `kubectl -n tak rollout restart deployment/opentakserver`

## Troubleshooting

### Image Pull Errors

If k3s can't pull from local registry:

```bash
# Add registry to k3s registries.yaml
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml << EOF
mirrors:
  "node0:5000":
    endpoint:
      - "http://node0:5000"
EOF

# Restart k3s
sudo systemctl restart k3s
```

### Build Failures

```bash
# Check Docker has enough space
df -h

# Clean up old images
docker system prune -a

# Build with verbose output
docker build --progress=plain ...
```

### Multi-arch Support

To build for multiple architectures (if needed):

```bash
docker buildx create --use
docker buildx build --platform linux/arm64,linux/amd64 ...
```
