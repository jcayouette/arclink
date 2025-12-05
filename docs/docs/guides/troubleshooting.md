# Troubleshooting

Common issues and solutions for OpenTAKServer deployment.

## Image Pull Errors

### Symptom
Pods fail to start with `ImagePullBackOff` errors:
```text
Failed to pull image "node0.research.core:5000/opentakserver:latest": 
http: server gave HTTP response to HTTPS client
```

### Cause
This occurs in multi-node K3s clusters when agent nodes don't have the insecure registry configuration. By default, containerd tries to pull images using HTTPS, but the local Docker registry runs on HTTP.

### Solution

#### Quick Fix
1. Copy the registry configuration to all agent nodes:
```bash
for ip in $(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/master!="true")].status.addresses[?(@.type=="InternalIP")].address}'); do
  scp /etc/rancher/k3s/registries.yaml $ip:/tmp/registries.yaml
  ssh $ip "sudo mkdir -p /etc/rancher/k3s && sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml"
  ssh $ip "sudo systemctl restart k3s-agent || sudo systemctl restart k3s"
done
```

2. Delete the failing pod to trigger recreation:
```bash
kubectl -n tak delete pod -l app=opentakserver
```

#### Automated Fix
The `redeploy.sh` script now automatically distributes registry configuration to all nodes. Ensure you have SSH keys set up:

```bash
# Set up SSH keys once
./scripts/helpers/setup-ssh-keys.sh

# Then redeploy will automatically configure all nodes
./scripts/redeploy.sh
```

### Prevention
For new deployments:

1. **Single-node clusters**: No additional configuration needed
2. **Multi-node clusters**: 
   - Run `./scripts/helpers/setup-ssh-keys.sh` during initial setup
   - The configure.sh script will offer to automatically configure agent nodes
   - Or manually distribute `/etc/rancher/k3s/registries.yaml` to all nodes

## SSH and Passwordless Sudo

### Why It's Needed
Multi-node cluster management requires:
- **SSH keys**: For passwordless authentication between nodes
- **Passwordless sudo**: For automated service restarts and configuration

### Setup SSH Keys
```bash
./scripts/helpers/setup-ssh-keys.sh
```

This script:
- Generates SSH keys if they don't exist
- Copies keys to all cluster nodes
- Verifies passwordless SSH is working

### Setup Passwordless Sudo
If you encounter sudo password prompts, configure passwordless sudo on agent nodes:

```bash
for ip in <agent-node-ips>; do
  ssh -t $ip "echo '$USER ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/$USER && sudo chmod 0440 /etc/sudoers.d/$USER"
done
```

## Registry Configuration Format

The `/etc/rancher/k3s/registries.yaml` file must be present on **all nodes** (master and agents):

```yaml
mirrors:
  "node0.research.core:5000":
    endpoint:
      - "http://node0.research.core:5000"

configs:
  "node0.research.core:5000":
    tls:
      insecure_skip_verify: true
```

### Verifying Configuration

**Check if file exists on all nodes:**
```bash
for ip in $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'); do
  echo "=== Node $ip ==="
  ssh $ip "sudo cat /etc/rancher/k3s/registries.yaml 2>/dev/null || echo 'MISSING'"
done
```

**Verify registry is accessible:**
```bash
curl http://node0.research.core:5000/v2/_catalog
```

Should return:
```json
{"repositories":["opentakserver","opentakserver-ui"]}
```

## Common Issues

### Issue: Registry not responding
**Symptom:** `curl http://<registry>:5000/v2/_catalog` fails

**Solution:**
```bash
# Check if registry is running
docker ps | grep registry

# If not running, start it
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

### Issue: K3s service not found
**Symptom:** `Failed to restart k3s-agent.service: Unit k3s-agent.service not found`

**Cause:** Some nodes run `k3s.service` instead of `k3s-agent.service`

**Solution:** The redeploy script now handles both service names automatically.

### Issue: Images not building
**Symptom:** `docker/opentakserver/` not found

**Cause:** Build script being run from wrong directory

**Solution:** The `build.sh` script now detects its location and adjusts paths automatically. Can be run from either:
- Root directory: `./docker/build.sh`
- Docker directory: `cd docker && ./build.sh`

## Debugging Commands

**Check pod events:**
```bash
kubectl -n tak describe pod -l app=opentakserver | grep -A 20 "Events:"
```

**Check which node pod is scheduled on:**
```bash
kubectl -n tak get pods -o wide
```

**View pod logs:**
```bash
kubectl -n tak logs -l app=opentakserver -c ots
kubectl -n tak logs -l app=opentakserver -c nginx
```

**Test registry from specific node:**
```bash
ssh <node-ip> "curl -s http://node0.research.core:5000/v2/_catalog"
```

## Getting Help

If issues persist:

1. Check all pods are running: `kubectl -n tak get pods`
2. Review logs: `./scripts/helpers/logs.sh`
3. Check cluster status: `./scripts/helpers/status.sh`
4. Verify registry configuration on all nodes (see above)
5. Ensure SSH keys are configured for multi-node clusters
