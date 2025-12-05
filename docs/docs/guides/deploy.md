---
sidebar_position: 3
---

# Manual Deployment (Alternative Method)

:::tip Recommended Approach
For automated deployment, see the **[Quick Start Guide](./quickstart.md)** or **[Complete Deployment Guide](./complete-deployment.md)** which use Ansible for full automation.

**With Ansible:**
```bash
ansible-playbook playbooks/deploy-opentakserver-with-patches.yml --ask-become-pass
```
:::

This guide covers **manual deployment** using shell scripts and kubectl. Use this method if you:
- Already followed the [Manual Setup Guide](./setup.md)
- Have a running K3s cluster with images built
- Prefer kubectl and shell scripts over Ansible
- Need to deploy specific components individually

## Prerequisites Checklist

Before deploying manually, verify you have completed:

- ✅ **K3s Cluster**: Running with kubectl configured
- ✅ **Docker Registry**: Running on port 5000, K3s configured to trust it
- ✅ **Images Built**: OpenTAK Server and UI images built with `cd docker && ./setup.sh`
- ✅ **Images Pushed**: Both images available in registry (`curl http://localhost:5000/v2/_catalog`)
- ✅ **Manifests Updated**: YAML files have correct registry address and settings

## Quick Deployment

For automated deployment of all components:

```bash
./scripts/deploy.sh
```

This script deploys in the correct order and waits for each component to be ready.

## Comparison with Ansible

| Aspect | Ansible Method | Manual Scripts Method |
|--------|---------------|----------------------|
| **Prerequisites** | Bare metal servers | K3s + built images |
| **Command** | `ansible-playbook deploy-opentakserver-with-patches.yml` | `./scripts/deploy.sh` |
| **Socket.IO Patches** | Automatic during build | Requires manual Dockerfile edits |
| **Time** | 3-5 min (cached) | 2-3 min (if images built) |
| **Rollback** | Built-in with playbooks | Manual kubectl commands |
| **Best For** | Full automation | Existing deployments |

## Step-by-Step Deployment

For manual deployment or troubleshooting, follow these steps:

### Step 1: Deploy PostgreSQL

PostgreSQL must be running before OpenTAK Server starts.

```bash
kubectl apply -f manifests/postgres.yaml
```

**Wait for PostgreSQL to be ready:**
```bash
kubectl wait --for=condition=ready pod \
  -l app=postgres \
  -n opentakserver \
  --timeout=120s
```

**Verify PostgreSQL is running:**
```bash
kubectl get pods -n opentakserver | grep postgres

# Should show: postgres-xxx Running
```

### Step 2: Deploy RabbitMQ

RabbitMQ handles asynchronous tasks.

```bash
kubectl apply -f manifests/rabbitmq.yaml
```

**Wait for RabbitMQ:**
```bash
kubectl wait --for=condition=ready pod \
  -l app=rabbitmq \
  -n opentakserver \
  --timeout=120s
```

**Verify RabbitMQ:**
```bash
kubectl get pods -n opentakserver | grep rabbitmq

# Should show: rabbitmq-xxx Running
```

### Step 3: Deploy Nginx Configuration

This creates the ConfigMap for the Nginx reverse proxy.

```bash
kubectl apply -f manifests/nginx-config.yaml
```

**No pods to wait for**, this just creates configuration.

### Step 4: Deploy OpenTAK Server

Now deploy the main application with UI.

```bash
kubectl apply -f manifests/ots-with-ui-custom-images.yaml
```

This creates:
- Secrets (admin password, PostgreSQL password, Flask secrets)
- PersistentVolumeClaim (10Gi for data and certificates)
- Deployment (OpenTAK Server + Nginx sidecar)
- Services (NodePorts for external access)

**Wait for OpenTAK Server:**
```bash
kubectl wait --for=condition=ready pod \
  -l app=opentakserver \
  -n opentakserver \
  --timeout=300s
```

**First boot takes longer** (~2 minutes) for certificate generation. Subsequent starts are ~10 seconds.

### Step 5: Set Admin Password

**CRITICAL:** Change the default admin password immediately!

```bash
./scripts/helpers/set-admin-password.sh
```

Follow the prompts to set a secure password.

## What Gets Deployed

### Kubernetes Resources

**Namespace:**
- `opentakserver` - Isolates all TAK server resources

**Deployments:**
- `postgres` - PostgreSQL 17 database (1 replica)
- `rabbitmq` - RabbitMQ 4.0 message queue (1 replica)
- `opentakserver` - OpenTAK Server + Nginx UI (1 replica)

**Services:**
| Service | Type | Port | Purpose |
|---------|------|------|---------|
| postgres | ClusterIP | 5432 | Database access (internal) |
| rabbitmq | ClusterIP | 5672 | Message queue (internal) |
| opentakserver-service | NodePort | 31080 | Web UI (external) |
| opentakserver-service | NodePort | 31088 | TCP CoT (external) |
| opentakserver-service | NodePort | 31089 | SSL CoT (external) |

**Persistent Volumes:**
- `postgres-pv-claim` - 5Gi for PostgreSQL data (Longhorn/local-path)
- `opentakserver-pv-claim` - 10Gi for TAK data, certs, logs (Longhorn/local-path)

**Secrets:**
- `opentakserver-secret` - Contains encoded credentials and Flask secrets

### Deployment Sequence

The deployment follows this order to ensure dependencies are met:

1. **PostgreSQL** → Database must be ready for OpenTAK Server
2. **RabbitMQ** → Message queue must be ready
3. **Nginx ConfigMap** → Reverse proxy configuration
4. **OpenTAK Server** → Main application connects to PostgreSQL and RabbitMQ

**Total deployment time**: ~3-5 minutes (first boot), ~30 seconds (subsequent)

## Accessing Your OpenTAK Server

### Web Interface

Access the web UI using your configured address:

```text
http://<PRIMARY_NODE_ADDRESS>:31080
```

Examples:
- `http://192.168.1.100:31080`
- `http://takserver.local:31080`

**Default Credentials:**
- Username: `administrator`
- Password: (set during admin password script)

:::danger Security Warning
If you used the old default password (`password`), change it immediately:
```bash
./scripts/helpers/set-admin-password.sh
```
:::

### TAK Client Connections (ATAK/iTAK/WinTAK)

Configure your TAK clients to connect to:

**TCP CoT (Unencrypted) - Development Only**
- Host: `<PRIMARY_NODE_ADDRESS>`
- Port: `31088`
- **Not recommended for production** - no encryption

**SSL CoT (Encrypted) - Recommended**
- Host: `<PRIMARY_NODE_ADDRESS>`
- Port: `31089`
- **Requires client certificate** - Generate in web UI under Certificates

### Port Reference

| Port | Service | Protocol | Usage |
|------|---------|----------|-------|
| 31080 | Web UI | HTTP | Administration interface |
| 31088 | TCP CoT | TCP | Unencrypted CoT streaming |
| 31089 | SSL CoT | TCP/TLS | Encrypted CoT streaming (certificate required) |

## Verifying Deployment

### Check All Pods Are Running

```bash
kubectl get pods -n opentakserver
```

**Expected output:**
```text
NAME                            READY   STATUS    RESTARTS   AGE
postgres-xxx                    1/1     Running   0          5m
rabbitmq-xxx                    1/1     Running   0          4m
opentakserver-xxx               2/2     Running   0          3m
```

Note: `opentakserver-xxx` shows `2/2` because it has two containers (OpenTAK Server + Nginx).

### Check Services Are Exposed

```bash
kubectl get svc -n opentakserver
```

**Expected output:**
```text
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                           AGE
postgres                ClusterIP   10.43.100.1     <none>        5432/TCP                          5m
rabbitmq                ClusterIP   10.43.100.2     <none>        5672/TCP                          4m
opentakserver-service   NodePort    10.43.100.3     <none>        8080:31080/TCP,8088:31088/TCP...  3m
```

### Check Persistent Volumes

```bash
kubectl get pvc -n opentakserver
```

**Expected output:**
```text
NAME                      STATUS   VOLUME                  CAPACITY   ACCESS MODES   AGE
postgres-pv-claim         Bound    pvc-xxx                 5Gi        RWO            5m
opentakserver-pv-claim    Bound    pvc-yyy                 10Gi       RWO            3m
```

Both should show `STATUS: Bound`.

### Test Web UI Accessibility

```bash
# Test from deployment machine
curl -I http://192.168.1.100:31080

# Should return HTTP 200 or 302 (redirect to login)
```

### Check OpenTAK Server Logs

```bash
# View OpenTAK Server logs
kubectl logs -n opentakserver -l app=opentakserver -c opentakserver

# View Nginx logs
kubectl logs -n opentakserver -l app=opentakserver -c nginx

# Follow logs in real-time
kubectl logs -n opentakserver -l app=opentakserver -c opentakserver -f
```

**Healthy logs should show:**
- "Database connection successful"
- "RabbitMQ connection established"
- "Flask application started"
- "Socket.IO server running"

## First-Time Setup

### 1. Log Into Web UI

1. Open `http://<PRIMARY_NODE_ADDRESS>:31080`
2. Log in with username `administrator` and your password
3. You should see the OpenTAK Server dashboard

### 2. Generate Client Certificates (for SSL CoT)

For secure TAK client connections:

1. Navigate to **Certificates** in web UI
2. Click **Create New Certificate**
3. Enter details:
   - Common Name: User or device name
   - Expiry: 1 year (default) or custom
4. Download `.p12` file
5. Install on ATAK/iTAK device

### 3. Configure TAK Clients

On your ATAK/iTAK device:

1. **Import Certificate** (for SSL connections)
   - Settings → Network Preferences → Certificate Management
   - Import your `.p12` file

2. **Add Server Connection**
   - Settings → Network Preferences → Server Connections
   - Click **+** to add new connection:
     - **Address**: `<PRIMARY_NODE_ADDRESS>:31089`
     - **Protocol**: SSL
     - **Certificate**: Select your imported cert

3. **Test Connection**
   - Connection indicator should turn green
   - You should appear on the map in web UI

Clients need certificates - generate them in the web UI under **Certificates**.

## Verifying Deployment

### Check Pod Status

```bash
./scripts/helpers/status.sh
```

Expected output:
```text
NAMESPACE       NAME                                READY   STATUS    RESTARTS
opentakserver   postgres-0                          1/1     Running   0
opentakserver   rabbitmq-0                          1/1     Running   0
opentakserver   opentakserver-ui-5f8c7d9b4f-abcde   1/1     Running   0
opentakserver   opentakserver-7b9c6d8f5d-xyz12      1/1     Running   0
```

All pods should show `Running` status.

### Check Services

```bash
kubectl get svc -n opentakserver
```

Expected output:
```text
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
postgres            ClusterIP   10.43.x.x       <none>        5432/TCP
rabbitmq            ClusterIP   10.43.x.x       <none>        5672/TCP
opentakserver       NodePort    10.43.x.x       <none>        8080:31088/TCP,8089:31089/TCP
opentakserver-ui    NodePort    10.43.x.x       <none>        80:31080/TCP
```

### View Logs

```bash
./scripts/helpers/logs.sh
```

Select a pod to view its logs interactively.

## Configuration After Deployment

### First Login

1. Navigate to `http://<server>:31080`
2. Login with default credentials
3. Change admin password immediately
4. Configure server settings

### Generate Client Certificates

1. Go to **Certificates** menu
2. Click **Create Certificate**
3. Enter device/user name
4. Download certificate package
5. Install on ATAK/iTAK device

### Configure Data Packages

1. Navigate to **Data Packages**
2. Upload maps, icons, or plugins
3. Make available to connected clients

## Updating Your Deployment

### Update OpenTAK Server to New Version

To update to a newer version of OpenTAK Server:

**1. Update Docker images:**
```bash
# Pull latest OpenTAK Server code
cd docker/opentakserver

# Edit Dockerfile to specify version (or use latest)
# RUN pip install git+https://github.com/brian7704/OpenTAKServer.git@v1.2.4

# Rebuild images
cd ..
./setup.sh

# Push updated images
docker push localhost:5000/opentakserver:latest
docker push localhost:5000/opentakserver-ui:latest
```

**2. Redeploy with new images:**
```bash
./scripts/redeploy.sh
```

This will:
- Delete existing OpenTAK Server pod
- Pull updated images from registry
- Start new pod with updated code
- **Preserve** all data, certificates, and configuration

**3. Verify update:**
```bash
kubectl logs -n opentakserver -l app=opentakserver -c opentakserver

# Check version in logs
```

### Update Configuration (config.env changes)

If you change `config.env` settings:

**1. Update manifests with new config:**
```bash
./scripts/configure.sh --update-manifests-only
```

**2. Apply updated manifests:**
```bash
kubectl apply -f manifests/ots-with-ui-custom-images.yaml
```

**3. Restart pod to pick up changes:**
```bash
kubectl rollout restart deployment/opentakserver -n opentakserver
```

### Redeployment Options

**Soft Redeploy (Preserve Data):**
```bash
./scripts/redeploy.sh
```

This deletes and recreates pods but keeps:
- ✅ Database content
- ✅ Certificates
- ✅ User accounts
- ✅ Data packages
- ✅ Configuration

**Hard Reset (Clean Slate):**
```bash
./scripts/helpers/reset.sh
```

:::danger Data Loss Warning
This deletes ALL data including database, certificates, and user accounts!
:::

Use hard reset for:
- Testing fresh installation
- Fixing corrupted database
- Major configuration changes
- Starting over completely

## Multi-Node Cluster Setup

### Overview

For high availability or load distribution, deploy Arclink across multiple K3s nodes.

**Requirements:**
- K3s cluster with 2+ nodes
- Docker registry accessible from all nodes
- Network connectivity between nodes

### Initial Setup on Primary Node

1. **Install K3s as server:**
```bash
curl -sfL https://get.k3s.io | sh -
```

2. **Get node token:**
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Save this token - you'll need it for worker nodes.

3. **Complete Arclink deployment** as documented above

### Add Worker Nodes

On each worker node:

**1. Join K3s cluster:**
```bash
# Replace with your primary node IP and token
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.100:6443 \
  K3S_TOKEN=your-node-token \
  sh -
```

**2. Configure Docker registry:**
```bash
sudo mkdir -p /etc/rancher/k3s
sudo nano /etc/rancher/k3s/registries.yaml
```

Add configuration:
```yaml
mirrors:
  "192.168.1.100:5000":  # Primary node IP
    endpoint:
      - "http://192.168.1.100:5000"
```

**3. Restart K3s on worker:**
```bash
sudo systemctl restart k3s-agent
```

**4. Verify worker joined:**
```bash
# On primary node
kubectl get nodes

# Should show all nodes as Ready
```

### Verify Multi-Node Deployment

```bash
# Check pods are distributed across nodes
kubectl get pods -n opentakserver -o wide

# Check node status
kubectl get nodes -o wide
```

### Multi-Node Considerations

**Storage:**
- Use Longhorn for distributed storage across nodes
- Local-path storage ties pods to specific nodes

**Networking:**
- NodePort services accessible on ANY node IP
- Use external load balancer for production

**High Availability:**
- Database replication (future enhancement)
- Multiple OpenTAK Server replicas (requires session affinity)

## Troubleshooting Deployment

### Issue: Pods Stuck in ImagePullBackOff

**Symptoms**: Pods won't start, show `ImagePullBackOff` or `ErrImagePull`

**Diagnosis:**
```bash
kubectl describe pod -n opentakserver <pod-name>
```

Look for: `Failed to pull image`

**Solutions:**

**1. Verify images exist in registry:**
```bash
curl http://localhost:5000/v2/_catalog

# Should list: opentakserver, opentakserver-ui
```

**2. Check K3s registry configuration:**
```bash
cat /etc/rancher/k3s/registries.yaml

# Ensure registry listed with http:// endpoint
```

**3. Restart K3s:**
```bash
sudo systemctl restart k3s
```

**4. On multi-node, check workers can reach registry:**
```bash
# On worker node
curl http://192.168.1.100:5000/v2/_catalog
```

### Issue: Pod CrashLoopBackOff

**Symptoms**: Pod starts but keeps crashing

**Diagnosis:**
```bash
kubectl logs -n opentakserver <pod-name> -c opentakserver --previous

# Check logs from crashed container
```

**Common causes and solutions:**

**Database connection failure:**
```bash
# Verify PostgreSQL is running
kubectl get pods -n opentakserver | grep postgres

# Check PostgreSQL logs
kubectl logs -n opentakserver <postgres-pod>
```

**Missing environment variables:**
```bash
# Verify secret exists
kubectl get secret -n opentakserver opentakserver-secret

# Check secret has all keys
kubectl describe secret -n opentakserver opentakserver-secret
```

**Incorrect credentials:**
```bash
# Regenerate config and redeploy
./scripts/configure.sh
./scripts/redeploy.sh
```

### Issue: Web UI Not Accessible

**Symptoms**: Cannot reach `http://<address>:31080`

**Diagnosis:**

**1. Check pod is running:**
```bash
kubectl get pods -n opentakserver | grep opentakserver
```

**2. Check service is exposed:**
```bash
kubectl get svc -n opentakserver opentakserver-service
```

**3. Verify NodePort configuration:**
```bash
kubectl describe svc -n opentakserver opentakserver-service | grep NodePort
```

**Solutions:**

**Firewall blocking port:**
```bash
# Check if port is listening
sudo netstat -tuln | grep 31080

# Allow port in firewall (example for ufw)
sudo ufw allow 31080/tcp
```

**Wrong PRIMARY_NODE_ADDRESS:**
```bash
# Get actual node IP
kubectl get nodes -o wide

# Use that IP instead
```

**Pod not ready:**
```bash
# Wait for pod to be ready
kubectl wait --for=condition=ready pod \
  -l app=opentakserver \
  -n opentakserver \
  --timeout=300s
```

### Issue: PostgreSQL Volume Mount Failure

**Symptoms**: PostgreSQL pod won't start, volume mount errors

**Diagnosis:**
```bash
kubectl describe pod -n opentakserver <postgres-pod>

# Look for: FailedMount, volume not found
```

**Solutions:**

**Storage class not available:**
```bash
# Check storage classes
kubectl get storageclass

# If longhorn not installed, use local-path
kubectl patch pvc postgres-pv-claim -n opentakserver \
  -p '{"spec":{"storageClassName":"local-path"}}'
```

**Insufficient storage:**
```bash
# Check node disk space
df -h

# Reduce PVC size in postgres.yaml if needed
```

### Issue: SSL CoT Connections Fail

**Symptoms**: TCP CoT works, but SSL connections fail or timeout

**Diagnosis:**
```bash
# Check certificates were generated
kubectl exec -n opentakserver <opentakserver-pod> -c opentakserver -- \
  ls -la /data/ca

# Should see CA certificate and keys
```

**Solutions:**

**Certificates not generated yet:**
```bash
# Wait for first boot to complete (generates certs)
kubectl logs -n opentakserver -l app=opentakserver -c opentakserver -f

# Look for: "Certificate authority created"
```

**Client certificate not installed:**
- Regenerate certificate in web UI
- Download .p12 file
- Install on ATAK/iTAK device

**Wrong port:**
- Use port 31089 for SSL CoT
- Use port 31088 for TCP CoT (unencrypted)

## Security Recommendations for Production

### Change Default Passwords

Immediately after deployment:

```bash
# Admin password
./scripts/helpers/set-admin-password.sh

# For extra security, also change database passwords
kubectl edit secret -n opentakserver opentakserver-secret
```

### Enable HTTPS for Web UI

Production deployments should use HTTPS:

1. **Option 1: Use Ingress with cert-manager**
   - Install ingress-nginx
   - Install cert-manager for Let's Encrypt
   - Create Ingress resource with TLS

2. **Option 2: Use external load balancer with SSL termination**
   - Configure your load balancer (nginx, HAProxy, etc.)
   - Terminate SSL at load balancer
   - Forward to NodePort 31080

### Restrict Network Access

```bash
# Use Kubernetes NetworkPolicy to restrict traffic
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: opentakserver-netpol
  namespace: opentakserver
spec:
  podSelector:
    matchLabels:
      app: opentakserver
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # Allow from same namespace
    ports:
    - protocol: TCP
      port: 8081
EOF
```

### Regular Backups

**Backup PostgreSQL database:**
```bash
kubectl exec -n opentakserver <postgres-pod> -- \
  pg_dump -U postgres opentakserver > backup-$(date +%Y%m%d).sql
```

**Backup certificates and data:**
```bash
kubectl exec -n opentakserver <opentakserver-pod> -c opentakserver -- \
  tar czf - /data | cat > opentakserver-data-$(date +%Y%m%d).tar.gz
```

## Maintenance Operations

### View Real-Time Logs

```bash
# OpenTAK Server logs
kubectl logs -n opentakserver -l app=opentakserver -c opentakserver -f

# Nginx logs
kubectl logs -n opentakserver -l app=opentakserver -c nginx -f

# PostgreSQL logs
kubectl logs -n opentakserver -l app=postgres -f
```

### Check Resource Usage

```bash
# Pod resource consumption
kubectl top pods -n opentakserver

# Node resource consumption
kubectl top nodes
```

### Scale Deployment (Future)

Currently single replica, but for future horizontal scaling:

```bash
# Scale OpenTAK Server (requires session affinity)
kubectl scale deployment/opentakserver -n opentakserver --replicas=3
```

:::info
Horizontal scaling requires additional configuration for session management and database connection pooling.
:::

## Next Steps

After successful deployment:
1. **Secure your installation** - Change passwords, enable HTTPS
2. **Configure backups** - Regular database and certificate backups
3. **Add TAK clients** - Generate certificates and connect ATAK/iTAK devices
4. **Monitor performance** - Use `kubectl top` and logs
5. **Plan for HA** - Consider multi-node setup with Longhorn storage

## Monitoring Deployment

### Watch Pod Creation

```bash
kubectl get pods -n opentakserver -w
```

Press Ctrl+C to stop watching.

### Check Events

```bash
kubectl get events -n opentakserver --sort-by='.lastTimestamp'
```

Shows recent cluster events and errors.

### Resource Usage

```bash
kubectl top pods -n opentakserver
```

Shows CPU and memory consumption.

## Scaling

### Horizontal Scaling (Multiple Replicas)

Currently, OpenTAK Server runs as a single replica. Future versions will support:

```yaml
spec:
  replicas: 3
```

### Vertical Scaling (More Resources)

Edit deployment to increase resources:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

Apply changes:
```bash
kubectl apply -f manifests/ots-with-ui-custom-images.yaml
```

## Updating

### Update Images

After rebuilding images:

```bash
# Rebuild images
cd docker && ./setup.sh

# Restart pods to pull new images
kubectl rollout restart deployment/opentakserver -n opentakserver
kubectl rollout restart deployment/opentakserver-ui -n opentakserver
```

### Update Configuration

After changing `config.env`:

```bash
# Regenerate manifests
./scripts/configure.sh

# Apply changes
./scripts/deploy.sh
```

## Backup

### Database Backup

```bash
kubectl exec -n opentakserver postgres-0 -- \
  pg_dump -U postgres opentakserver > backup.sql
```

### Certificate Backup

```bash
kubectl exec -n opentakserver opentakserver-xxx -- \
  tar czf - /data/ca > ca-backup.tar.gz
```

### Full Backup

```bash
# Backup PostgreSQL data
kubectl exec -n opentakserver postgres-0 -- \
  tar czf - /var/lib/postgresql/data > postgres-data.tar.gz

# Backup OpenTAK data
kubectl exec -n opentakserver opentakserver-xxx -- \
  tar czf - /data > ots-data.tar.gz
```

## Restore

### Database Restore

```bash
cat backup.sql | kubectl exec -i -n opentakserver postgres-0 -- \
  psql -U postgres opentakserver
```

### Certificate Restore

```bash
kubectl exec -i -n opentakserver opentakserver-xxx -- \
  tar xzf - -C / < ca-backup.tar.gz
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod details
kubectl describe pod <pod-name> -n opentakserver

# Check events
kubectl get events -n opentakserver

# Check logs
kubectl logs <pod-name> -n opentakserver
```

### Cannot Access Web UI

```bash
# Verify service
kubectl get svc opentakserver-ui -n opentakserver

# Check pod logs
kubectl logs -l app=opentakserver-ui -n opentakserver

# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://opentakserver-ui.opentakserver.svc.cluster.local
```

### Database Connection Errors

```bash
# Check PostgreSQL pod
kubectl logs postgres-0 -n opentakserver

# Test connection
kubectl exec -it postgres-0 -n opentakserver -- \
  psql -U postgres -c '\l'
```

### Image Pull Errors

```bash
# Check registry accessibility
curl http://localhost:5000/v2/_catalog

# Verify image exists
docker pull localhost:5000/opentakserver:latest

# Check K3s registry config
cat /etc/rancher/k3s/registries.yaml
```

## Performance Tuning

### Adjust Pod Resources

Based on your hardware:

```yaml
# Low-end (Raspberry Pi)
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"

# High-end (Server)
resources:
  requests:
    memory: "2Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Storage Performance

For better I/O:
- Use SSD/NVMe storage
- Increase volume size
- Use Longhorn with SSD backing

## Next Steps

After successful deployment:
- [Configure client devices](../raspberry-pi/hardware.md)
- [Set up monitoring](#) (coming soon)
- [Enable high availability](#) (coming soon)
