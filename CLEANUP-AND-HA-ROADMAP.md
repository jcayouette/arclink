# Arclink Cleanup & Next Steps Checklist

## Potential Cleanup Tasks

### Minor Cleanup (Optional)

#### 1. Playbook Consolidation
**Current State:** We have some similar playbooks that could be merged:
- [ ] Consider merging `build-docker-images.yml` and `build-ots-images.yml` (they're very similar)
- [ ] Consider merging `restart-k3s-inline.yml` and `restart-k3s.yml`
- [ ] Evaluate if `setup-kubectl-node0.yml` is needed separately

**Decision:** Keep them separate for now - having specific playbooks makes workflows clearer

#### 2. Update CHANGES.md
- [ ] Sync CHANGES.md with release-notes.md content
- [ ] Ensure all recent work is documented

#### 3. Documentation Review
- [ ] Review `docs/docs/guides/deploy.md` - May overlap with new quickstart.md
- [ ] Review `docs/docs/guides/setup.md` - May overlap with complete-deployment.md
- [ ] Decide if old guides should be updated or deprecated

---

## Repository Structure Assessment

```
arclink/
├── .github/workflows/           ✅ GitHub Actions configured
├── ansible/                     ✅ Complete automation suite
│   ├── inventory/               ✅ Production-ready
│   ├── playbooks/ (15)          ✅ All documented
│   ├── roles/ (5)               ✅ All in use
│   └── docs (2 .md)             ✅ Clear instructions
├── docker/                      ✅ Build scripts functional
│   ├── opentakserver/           ✅ Dockerfile present
│   └── ui/                      ✅ Dockerfile present
├── docs/                        ✅ Comprehensive Docusaurus site
│   ├── docs/guides/             ✅ Main guides (6 files)
│   ├── docs/guides/ansible/     ✅ Ansible guides (6 files)
│   └── docs/raspberry-pi/       ✅ Pi-specific docs (2 files)
├── manifests/                   ✅ K8s manifests (6 files)
├── scripts/                     ✅ Helper scripts (3 main, 5 helpers)
├── README.md                    ⚠️  Could highlight Ansible more
├── CHANGES.md                   ⚠️  Needs update
├── config.env.example           ✅ Template ready
└── LICENSE                      ✅ Present
```

### Status Legend
- ✅ Clean and functional
- ⚠️  Minor updates recommended
- ❌ Needs attention

---

## High Priority Items

### 1. Update Main README.md
- [ ] Highlight Ansible automation as primary deployment method
- [ ] Add badges (build status, docs, license)
- [ ] Update quick start to focus on Ansible
- [ ] Add link to documentation site prominently

### 2. Update CHANGES.md
- [ ] Sync with release notes
- [ ] Document v0.2.0 features
- [ ] Add breaking changes section if any

### 3. Review Old Documentation Guides
**Files to review:**
- [ ] `docs/docs/guides/deploy.md` - 1092 lines, may be outdated
- [ ] `docs/docs/guides/setup.md` - Check if overlaps with new guides
- [ ] Decide: Update, deprecate, or keep as alternative manual method

---

## Next Steps: High Availability for OpenTAKServer

### Phase 1: Planning & Design ⏳

#### 1.1 Architecture Design
- [ ] Review current single-instance deployment
- [ ] Design multi-replica architecture
- [ ] Plan session persistence strategy
- [ ] Design load balancing approach
- [ ] Document state management requirements

#### 1.2 Session Management
- [ ] Research OpenTAKServer session handling
- [ ] Evaluate Redis for shared sessions
- [ ] Design Redis deployment (standalone vs cluster)
- [ ] Plan session affinity vs shared storage

#### 1.3 Database High Availability
- [ ] Current: Single PostgreSQL instance
- [ ] Plan: PostgreSQL replication (primary + replicas)
- [ ] Evaluate: Patroni, CloudNativePG, or Zalando operator
- [ ] Design automated failover

#### 1.4 Load Balancing
- [ ] Current: NodePort (31080)
- [ ] Option 1: MetalLB with LoadBalancer service
- [ ] Option 2: HAProxy/nginx external LB
- [ ] Option 3: Kubernetes Ingress with SSL termination
- [ ] Decision: ???

---

### Phase 2: Redis Implementation 🎯

#### 2.1 Redis Deployment
- [ ] Create `manifests/redis.yaml`
- [ ] Deploy Redis in `tak` namespace
- [ ] Configure persistence (RDB + AOF)
- [ ] Set resource limits

#### 2.2 Redis High Availability (Optional for Phase 2)
- [ ] Deploy Redis Sentinel (3 instances)
- [ ] Configure automatic failover
- [ ] Test failover scenarios

#### 2.3 OpenTAKServer Redis Integration
- [ ] Research OTS session configuration
- [ ] Modify environment variables for Redis connection
- [ ] Update manifests with Redis settings
- [ ] Test session persistence across pods

#### 2.4 Ansible Automation
- [ ] Create `playbooks/deploy-redis.yml`
- [ ] Add Redis role (optional)
- [ ] Update `deploy-opentakserver-with-patches.yml` to include Redis
- [ ] Document Redis configuration in guides

---

### Phase 3: Multi-Replica Deployment 🎯

#### 3.1 OpenTAKServer Scaling
- [ ] Update `ots-with-ui-custom-images.yaml`:
  - [ ] Set `replicas: 3` (or more)
  - [ ] Add pod anti-affinity rules (spread across nodes)
  - [ ] Configure resource requests/limits
  - [ ] Add liveness/readiness probes

#### 3.2 Service Configuration
- [ ] Update Service to handle multiple pods
- [ ] Configure session affinity (if not using Redis)
- [ ] Test load distribution

#### 3.3 Testing
- [ ] Deploy with multiple replicas
- [ ] Test pod failure scenarios
- [ ] Verify session persistence
- [ ] Load testing

---

### Phase 4: Database High Availability 🔮

#### 4.1 PostgreSQL Operator Evaluation
Options to evaluate:
- [ ] CloudNativePG (recommended, CNCF project)
- [ ] Zalando PostgreSQL Operator
- [ ] Crunchy PostgreSQL Operator
- [ ] Stolon

#### 4.2 PostgreSQL Cluster Deployment
- [ ] Install chosen operator
- [ ] Create PostgreSQL cluster manifest
- [ ] Configure replication (1 primary + 2 replicas)
- [ ] Setup automated failover
- [ ] Configure backups

#### 4.3 Migration
- [ ] Backup current PostgreSQL data
- [ ] Deploy new HA PostgreSQL cluster
- [ ] Migrate data
- [ ] Update OpenTAKServer connection string
- [ ] Verify application connectivity

#### 4.4 Ansible Automation
- [ ] Create `playbooks/deploy-postgres-ha.yml`
- [ ] Add operator installation tasks
- [ ] Add cluster deployment tasks
- [ ] Document in guides

---

### Phase 5: Load Balancing 🔮

#### 5.1 MetalLB Deployment (Recommended)
- [ ] Create `playbooks/deploy-metallb.yml`
- [ ] Install MetalLB in `metallb-system` namespace
- [ ] Configure IP address pool
- [ ] Set L2 advertisement mode

#### 5.2 LoadBalancer Service
- [ ] Convert NodePort to LoadBalancer service
- [ ] Assign external IP from MetalLB pool
- [ ] Test external access
- [ ] Update documentation

#### 5.3 Alternative: Ingress Controller
- [ ] Option: Deploy nginx-ingress or Traefik
- [ ] Create Ingress resource
- [ ] Configure SSL/TLS termination
- [ ] Setup cert-manager for Let's Encrypt

---

### Phase 6: Monitoring & Observability 🔮

#### 6.1 Prometheus Stack
- [ ] Deploy kube-prometheus-stack
- [ ] Configure ServiceMonitors for OTS
- [ ] Setup PostgreSQL exporter
- [ ] Setup Redis exporter

#### 6.2 Grafana Dashboards
- [ ] Create OpenTAKServer dashboard
- [ ] Create PostgreSQL dashboard
- [ ] Create Redis dashboard
- [ ] Create cluster overview dashboard

#### 6.3 Alerting
- [ ] Configure Alertmanager
- [ ] Define alert rules (pod down, high latency, etc.)
- [ ] Setup notification channels

#### 6.4 Logging
- [ ] Option 1: Loki + Promtail
- [ ] Option 2: ELK/EFK stack
- [ ] Centralize logs from all OTS pods

---

### Phase 7: Backup & Disaster Recovery 🔮

#### 7.1 Velero Deployment
- [ ] Install Velero for cluster backups
- [ ] Configure backup storage (S3, NFS, etc.)
- [ ] Setup automated backup schedule
- [ ] Test restore procedures

#### 7.2 Database Backups
- [ ] Automated PostgreSQL backups
- [ ] Point-in-time recovery setup
- [ ] Backup retention policy
- [ ] Test restore procedures

#### 7.3 Disaster Recovery Plan
- [ ] Document recovery procedures
- [ ] Create runbooks for common failures
- [ ] Test full cluster recovery
- [ ] Automate recovery with Ansible

---

## Priority Order

### Immediate (Week 1-2)
1. ✅ Update README.md to highlight Ansible
2. ✅ Update CHANGES.md
3. ⏳ Review and update/deprecate old docs guides

### Short Term (Week 3-4) - Phase 2
4. 🎯 Deploy Redis for session management
5. 🎯 Integrate Redis with OpenTAKServer
6. 🎯 Test session persistence

### Medium Term (Month 2) - Phase 3
7. 🎯 Multi-replica OpenTAKServer deployment
8. 🎯 Load testing and optimization
9. 🎯 Documentation updates

### Long Term (Month 3+) - Phases 4-7
10. 🔮 PostgreSQL HA with operator
11. 🔮 MetalLB for load balancing
12. 🔮 Monitoring stack
13. 🔮 Backup and DR procedures

---

## Success Criteria

### Phase 2 Complete
- [ ] Redis deployed and running
- [ ] OpenTAKServer using Redis for sessions
- [ ] Sessions persist across pod restarts
- [ ] Documentation updated

### Phase 3 Complete
- [ ] Multiple OTS pods running (3+)
- [ ] Load distributed across pods
- [ ] Pod failure doesn't lose sessions
- [ ] Performance validated

### Phase 4 Complete
- [ ] PostgreSQL cluster with replication
- [ ] Automated failover tested
- [ ] Zero downtime during DB failover
- [ ] Backup/restore procedures validated

### Phase 5 Complete
- [ ] External LoadBalancer assigned
- [ ] SSL/TLS termination configured
- [ ] Traffic distributed across pods
- [ ] HA validated end-to-end

---

## Questions to Answer

### Redis Session Management
- [ ] Does OpenTAKServer support Redis for sessions natively?
- [ ] What environment variables/config needed?
- [ ] Does Socket.IO support Redis adapter?
- [ ] Session serialization format?

### Load Balancing
- [ ] Does OpenTAKServer require sticky sessions?
- [ ] Are WebSocket connections maintained correctly with LB?
- [ ] What's the best LB strategy for Socket.IO?

### State Management
- [ ] What state is stored locally in OTS pods?
- [ ] Is all state in PostgreSQL or local files?
- [ ] Are there any singleton services/background jobs?

---

## Documentation to Create

- [ ] `docs/docs/guides/ansible/redis-deployment.md`
- [ ] `docs/docs/guides/ansible/multi-replica-ots.md`
- [ ] `docs/docs/guides/ansible/postgresql-ha.md`
- [ ] `docs/docs/guides/ansible/metallb-setup.md`
- [ ] `docs/docs/guides/ansible/monitoring.md`
- [ ] Update `docs/docs/guides/ansible/high-availability.md` with implementation details

---

## Notes

**Current State:**
- ✅ K3s cluster with 7 nodes (3 masters + 4 agents)
- ✅ Longhorn distributed storage
- ✅ Single instance OpenTAKServer with Socket.IO patches
- ✅ Single PostgreSQL instance
- ✅ Single RabbitMQ instance
- ✅ NodePort access (31080)

**Target State:**
- 🎯 Multi-replica OpenTAKServer (3+ pods)
- 🎯 Redis for session management
- 🔮 PostgreSQL HA cluster
- 🔮 RabbitMQ cluster (3 nodes)
- 🔮 LoadBalancer service
- 🔮 Monitoring and alerting
- 🔮 Automated backups

**Philosophy:**
- Incremental improvements
- Test each phase thoroughly
- Document as we go
- Maintain backward compatibility
- Keep simple single-node deployment option
