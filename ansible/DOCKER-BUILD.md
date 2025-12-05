# OpenTAKServer Deployment with Socket.IO Patches

This playbook automates the complete process of building Docker images with Socket.IO patches and deploying OpenTAKServer to K3s.

## What It Does

1. **Configures Docker** for insecure registry access
2. **Builds Docker images** with Socket.IO patches:
   - Adds CORS headers (`cors_allowed_origins='*'`)
   - Removes RabbitMQ message_queue
   - Increases ping timeout to 60 seconds
3. **Pushes images** to local registry
4. **Deploys** OpenTAKServer with patched images
5. **Verifies** patches are present in running container

## Prerequisites

- K3s cluster running
- Docker installed on build node
- kubectl configured
- Docker registry running at `node0.research.core:5000`

## Usage

### One-Command Deployment

```bash
cd /home/acmeastro/arclink/ansible
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```

The playbook will:
- Prompt for sudo password (needed for Docker configuration)
- Build images (~3-5 minutes on cached builds)
- Push to registry
- Deploy to K3s
- Verify patches

### Configuration

All configuration is in `roles/docker-build/defaults/main.yml`:

```yaml
registry_address: "node0.research.core:5000"
registry_ip: "10.0.0.160:5000"
ots_version: "1.6.3"
ui_version: "master"
namespace: "tak"
```

To override, use `-e` flag:

```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml \
  -e "ots_version=1.6.4" \
  --ask-become-pass
```

## Manual Alternative

If ansible-playbook is not available, use the shell script:

```bash
cd /home/acmeastro/arclink
./scripts/build-and-deploy.sh
```

## Troubleshooting

### Check build logs
```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml -vv
```

### Verify patches manually
```bash
POD=$(kubectl get pod -n tak -l app=opentakserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tak ${POD} -c opentakserver -- \
  grep "cors_allowed_origins" /app/venv/lib/python3.12/site-packages/opentakserver/extensions.py
```

### Check websocket logs
```bash
kubectl logs -n tak ${POD} -c nginx --tail=50 | grep socket.io
```

Expected: HTTP 200 responses (not 400 errors)

## Files

- `playbooks/deploy-opentakserver-with-patches.yml` - Main playbook
- `roles/docker-build/` - Docker build and push role
- `scripts/build-and-deploy.sh` - Standalone shell script
- `docker/opentakserver/Dockerfile` - Image with Socket.IO patches

## Notes

- First build takes ~30 minutes
- Subsequent builds use cache (~3-5 minutes)
- Images are pushed to local registry for cluster-wide access
- Deployment manifest at `/tmp/ots-deployment-fixed.yaml`
