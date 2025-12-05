---
sidebar_position: 2
---

# High Availability Setup

:::info Status
This guide documents implementing high availability (HA) for OpenTAK Server. This builds on the 3-node K3s cluster setup from the [progress checklist](./progress-checklist.md) and adds application-level HA with multiple replicas and automatic failover.
:::

## Overview

By default, Arclink runs a single OpenTAK Server pod. If that pod fails, Kubernetes automatically restarts it with ~10-30 seconds of downtime. This guide walks through implementing true high availability with multiple replicas and automatic failover.

## Current Architecture Limitations

The current single-replica architecture has these characteristics:

- ✅ **Automatic restart**: K3s restarts failed pods
- ✅ **Health monitoring**: Liveness/readiness probes detect failures
- ❌ **Downtime during restarts**: 10-30 seconds while pod recovers
- ❌ **No horizontal scaling**: Flask sessions and Socket.IO are in-process
- ❌ **Single point of failure**: One pod serves all traffic

## HA Architecture Goals

What we want to achieve:

1. **Multiple replicas**: 2-3 OpenTAK Server pods running simultaneously
2. **Automatic failover**: Traffic shifts to healthy pods instantly
3. **Zero-downtime updates**: Rolling updates without service interruption
4. **Session persistence**: Users stay logged in across pod restarts
5. **Database redundancy**: PostgreSQL with replication (future)

## Implementation Phases

### Phase 1: Multi-Replica with Sticky Sessions (Minimal HA)

**Goal**: Run multiple pods with client session affinity

**Downtime**: None (can be done with rolling update)

**What it provides**:
- Automatic failover to other pods
- Zero-downtime deployments
- User logged out only if their specific pod dies

**Limitations**:
- Sessions lost if a pod dies
- Certificates must be shared between pods

**Steps**:

#### 1.1 Enable Session Affinity

Edit `manifests/ots-with-ui-custom-images.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: opentakserver-service
  namespace: opentakserver
spec:
  type: NodePort
  sessionAffinity: ClientIP  # ADD THIS
  sessionAffinityConfig:      # ADD THIS
    clientIP:
      timeoutSeconds: 10800  # 3 hours
  selector:
    app: opentakserver
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 31080
    - name: tcp-cot
      port: 8088
      targetPort: 8088
      nodePort: 31088
    - name: ssl-cot
      port: 8089
      targetPort: 8089
      nodePort: 31089
```

#### 1.2 Increase Replicas

In the same file, update the Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opentakserver
  namespace: opentakserver
spec:
  replicas: 2  # CHANGE FROM 1 TO 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0  # ADD THIS - never take all pods down
      maxSurge: 1        # ADD THIS - create new before killing old
  selector:
    matchLabels:
      app: opentakserver
  template:
    # ... rest of pod spec
```

#### 1.3 Configure Shared Storage for Certificates

Update PersistentVolumeClaim to use ReadWriteMany (requires Longhorn):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: opentakserver-pv-claim
  namespace: opentakserver
spec:
  accessModes:
    - ReadWriteMany  # CHANGE FROM ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

:::warning
ReadWriteMany requires Longhorn or NFS. If using local-path storage, you must store certificates differently (see Phase 2).
:::

#### 1.4 Apply Changes

```bash
# Apply updated manifests
kubectl apply -f manifests/ots-with-ui-custom-images.yaml

# Watch rollout
kubectl rollout status deployment/opentakserver -n opentakserver

# Verify multiple pods running
kubectl get pods -n opentakserver -l app=opentakserver
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS   AGE
opentakserver-abc123-xyz        2/2     Running   0          2m
opentakserver-abc123-def        2/2     Running   0          2m
```

#### 1.5 Test Failover

```bash
# Delete one pod to simulate failure
kubectl delete pod -n opentakserver -l app=opentakserver --field-selector metadata.name=opentakserver-abc123-xyz

# Traffic should continue on remaining pod
# Kubernetes creates replacement pod automatically

# Verify service continues
curl http://<PRIMARY_NODE_ADDRESS>:31080
```

### Phase 2: Shared Session Store (Full HA)

**Goal**: Use Redis for shared sessions so any pod can serve any request

**What it provides**:
- Sessions survive pod restarts
- True load balancing across all pods
- No session affinity needed

**Prerequisites**:
- Phase 1 completed
- Redis deployed in cluster

**Steps**:

#### 2.1 Deploy Redis

Create `manifests/redis.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: opentakserver
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: opentakserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-data
        emptyDir: {}
```

Deploy:
```bash
kubectl apply -f manifests/redis.yaml
```

#### 2.2 Update OpenTAK Server to Use Redis Sessions

This requires modifying the OpenTAK Server code. Create a patch file:

`docker/opentakserver/redis-session.patch`:

```patch
--- a/opentakserver/__init__.py
+++ b/opentakserver/__init__.py
@@ -1,5 +1,6 @@
 from flask import Flask
 from flask_sqlalchemy import SQLAlchemy
+from flask_session import Session
 from flask_security import Security, SQLAlchemyUserDatastore
 
 app = Flask(__name__)
@@ -8,6 +9,13 @@
 app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
 app.config['SECURITY_PASSWORD_SALT'] = os.getenv('SECURITY_PASSWORD_SALT')
 
+# Redis session configuration
+app.config['SESSION_TYPE'] = 'redis'
+app.config['SESSION_REDIS'] = redis.from_url(os.getenv('REDIS_URL', 'redis://redis:6379/0'))
+app.config['SESSION_PERMANENT'] = True
+app.config['PERMANENT_SESSION_LIFETIME'] = 3600 * 24  # 24 hours
+Session(app)
+
 db = SQLAlchemy(app)
```

#### 2.3 Rebuild Images with Redis Support

Update `docker/opentakserver/Dockerfile`:

```dockerfile
# Add redis and flask-session to requirements
RUN pip install redis flask-session
```

Rebuild and push:
```bash
cd docker
./setup.sh
```

#### 2.4 Update Deployment Environment

Add Redis URL to opentakserver secret in `manifests/ots-with-ui-custom-images.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: opentakserver-secret
  namespace: opentakserver
type: Opaque
stringData:
  admin-password: "${OTS_ADMIN_PASSWORD}"
  postgres-password: "${POSTGRES_PASSWORD}"
  rabbitmq-password: "${RABBITMQ_PASSWORD}"
  secret-key: "${SECRET_KEY}"
  security-password-salt: "${SECURITY_PASSWORD_SALT}"
  redis-url: "redis://redis:6379/0"  # ADD THIS
```

Update container env vars:
```yaml
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: opentakserver-secret
      key: redis-url
```

#### 2.5 Remove Session Affinity

Now that sessions are shared, remove sticky sessions:

```yaml
spec:
  type: NodePort
  # REMOVE sessionAffinity and sessionAffinityConfig
  selector:
    app: opentakserver
```

#### 2.6 Deploy and Test

```bash
# Apply updated manifests
./scripts/redeploy.sh

# Test session persistence
# 1. Log in to web UI
# 2. Delete the pod you're connected to
kubectl delete pod -n opentakserver <pod-name>
# 3. Refresh browser - you should stay logged in
```

### Phase 3: Pod Disruption Budget (Prevent Outages)

Add protection against disruptions:

Create `manifests/pdb.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: opentakserver-pdb
  namespace: opentakserver
spec:
  minAvailable: 1  # Always keep at least 1 pod running
  selector:
    matchLabels:
      app: opentakserver
```

Deploy:
```bash
kubectl apply -f manifests/pdb.yaml
```

### Phase 4: PostgreSQL High Availability (Future)

For true database redundancy, consider:

**Option 1: Patroni Operator**
- PostgreSQL with automatic failover
- Leader election via etcd
- Automatic replica promotion

**Option 2: CloudNativePG Operator**
- Modern PostgreSQL operator
- Built-in replication
- Backup/restore support

**Option 3: Managed Database**
- AWS RDS, Google Cloud SQL, etc.
- Fully managed HA
- Automatic backups

## Monitoring HA Setup

### Check Pod Distribution

```bash
# See which nodes pods are running on
kubectl get pods -n opentakserver -o wide

# Pods should be spread across nodes if possible
```

### Monitor Replica Status

```bash
# Watch pods in real-time
kubectl get pods -n opentakserver -w

# Check replica count
kubectl get deployment opentakserver -n opentakserver
```

### Test Failover

```bash
# Delete a pod and watch automatic recovery
kubectl delete pod -n opentakserver <pod-name>

# Pod should be recreated within seconds
# Service should continue without interruption
```

### Check Session Distribution

If using Redis sessions:
```bash
# Connect to Redis
kubectl exec -it -n opentakserver <redis-pod> -- redis-cli

# Count active sessions
KEYS flask_session:*

# Check session details
GET flask_session:<session-id>
```

## Troubleshooting HA

### Issue: Pods Not Spreading Across Nodes

**Solution**: Add pod anti-affinity

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: opentakserver
              topologyKey: kubernetes.io/hostname
```

### Issue: Sessions Lost Despite Redis

**Diagnosis**:
```bash
# Check Redis is receiving connections
kubectl logs -n opentakserver -l app=redis

# Verify OTS can reach Redis
kubectl exec -n opentakserver <ots-pod> -c opentakserver -- ping redis
```

### Issue: ReadWriteMany PVC Pending

**Solutions**:
1. Install Longhorn (distributed storage system for Kubernetes)
2. Use NFS storage class
3. Store certificates in Kubernetes secrets instead

### Issue: Rolling Update Takes Down All Pods

**Fix**: Ensure `maxUnavailable: 0` in deployment strategy

## Performance Considerations

### Resource Requirements (Per Pod)

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

For 2 replicas, minimum cluster requirements:
- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Storage**: 50GB+ with Longhorn

### Database Connection Pooling

With multiple pods, configure connection pooling:

```python
# In OpenTAK Server config
SQLALCHEMY_ENGINE_OPTIONS = {
    'pool_size': 10,
    'max_overflow': 20,
    'pool_recycle': 3600
}
```

## Rollback Plan

If HA setup causes issues:

```bash
# Scale back to 1 replica
kubectl scale deployment opentakserver -n opentakserver --replicas=1

# Remove session affinity (edit service)
kubectl edit svc opentakserver-service -n opentakserver

# Revert to original manifests
git checkout manifests/ots-with-ui-custom-images.yaml
kubectl apply -f manifests/ots-with-ui-custom-images.yaml
```

## Success Criteria

✅ Phase 1 Complete:
- Multiple pods running
- Zero-downtime deployments work
- Failover happens automatically

✅ Phase 2 Complete:
- Sessions survive pod restarts
- Users stay logged in during updates
- Redis shows active sessions

✅ Phase 3 Complete:
- PDB prevents full outages
- Updates respect minimum availability

## Next Steps

After implementing HA:
1. Set up monitoring (Prometheus + Grafana)
2. Configure alerting for pod failures
3. Implement automated backups
4. Document disaster recovery procedures
5. Load test with multiple concurrent users

## Additional Resources

- [Kubernetes Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Flask-Session Documentation](https://flask-session.readthedocs.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/current/high-availability.html)
