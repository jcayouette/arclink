# OpenTAKServer Scripts

Management scripts for OpenTAKServer K3s deployment.

## Primary Scripts

These are the main scripts you'll use for deployment:

### `configure.sh`
Interactive configuration wizard that sets up everything:
- Checks prerequisites (kubectl, docker, K3s)
- Prompts for network settings (IP or DNS hostname)
- Generates secure random secrets
- Updates manifest files automatically
- Sets up Docker registry
- Configures K3s for insecure registry

**Usage:**
```bash
./scripts/configure.sh
```

**When to use:** First time setup, or when changing configuration

---

### `deploy.sh`
Deploys OpenTAKServer and all dependencies:
- Creates namespace
- Deploys PostgreSQL and RabbitMQ
- Deploys OpenTAKServer with custom images
- Waits for services to be ready
- Runs comprehensive health checks
- Shows access URLs and credentials

**Usage:**
```bash
./scripts/deploy.sh
```

**When to use:** After configuration, or to deploy after building new images

---

### `redeploy.sh`
Complete reset and fresh deployment:
- Deletes entire namespace (⚠️ destroys all data!)
- Waits for cleanup
- Runs fresh deployment
- Confirms before proceeding

**Usage:**
```bash
./scripts/redeploy.sh
```

**When to use:** Testing, major changes, or when you want to start completely fresh

---

## Helper Scripts

Additional management tools located in `scripts/helpers/`:

### `helpers/status.sh`
Shows deployment status and diagnostics:
- Pod status and health
- Services and endpoints
- Storage (PVCs)
- Quick diagnostics
- Watch mode available

**Usage:**
```bash
./scripts/helpers/status.sh          # One-time check
./scripts/helpers/status.sh --watch  # Continuous monitoring
```

**When to use:** Check deployment health, monitor startup progress

---

### `helpers/logs.sh`
Interactive log viewer for all components:
- OpenTAKServer (main app)
- Nginx proxy
- Init containers (setup, build-ui)
- PostgreSQL
- RabbitMQ
- Quick access via command line

**Usage:**
```bash
./scripts/helpers/logs.sh            # Interactive menu
./scripts/helpers/logs.sh ots        # Direct to OTS logs
./scripts/helpers/logs.sh nginx      # Direct to nginx logs
./scripts/helpers/logs.sh postgres   # Direct to postgres logs
```

**When to use:** Debugging issues, monitoring startup, troubleshooting

---

### `helpers/reset.sh`
Soft or hard reset of deployment:
- **Soft reset:** Restarts pods, keeps data
- **Hard reset:** Deletes namespace, destroys all data

**Usage:**
```bash
./scripts/helpers/reset.sh           # Soft reset (restart)
./scripts/helpers/reset.sh --hard    # Hard reset (delete all)
```

**When to use:** 
- Soft: Apply config changes, restart services
- Hard: Clean slate, remove everything

---

### `helpers/set-admin-password.sh`
Change administrator password:
- Reads from config.env
- Interactive password prompt
- Confirms password
- Updates database directly

**Usage:**
```bash
./scripts/helpers/set-admin-password.sh
```

**When to use:** Change default password, password recovery

---

## Typical Workflows

### First Time Setup
```bash
# 1. Configure everything
./scripts/configure.sh

# 2. Build images
cd docker && ./setup.sh

# 3. Deploy
./scripts/deploy.sh

# 4. Change default password
./scripts/helpers/set-admin-password.sh
```

### Check Deployment Status
```bash
# Quick check
./scripts/helpers/status.sh

# Continuous monitoring
./scripts/helpers/status.sh --watch

# View logs
./scripts/helpers/logs.sh
```

### Make Changes and Redeploy
```bash
# Soft reset (keep data)
./scripts/helpers/reset.sh

# Hard reset (fresh start)
./scripts/redeploy.sh
```

### Troubleshooting
```bash
# Check status
./scripts/helpers/status.sh

# View logs
./scripts/helpers/logs.sh ots

# Check specific pod
kubectl -n tak describe pod <pod-name>

# Get events
kubectl -n tak get events --sort-by='.lastTimestamp'
```

## Script Dependencies

All scripts use `config.env` for configuration. Make sure to run `configure.sh` first to generate this file.

**config.env contains:**
- Network addresses (IP or DNS)
- Port mappings
- Kubernetes settings
- Credentials
- Security secrets

## Notes

- All scripts check for prerequisites before running
- Interactive scripts require confirmation for destructive actions
- Helper scripts are non-destructive (except reset.sh --hard)
- Logs and status scripts work even during pod startup
