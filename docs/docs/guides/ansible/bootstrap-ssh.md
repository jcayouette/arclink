---
sidebar_position: 2
---

# Bootstrap SSH Access

Setting up passwordless SSH authentication to your cluster nodes.

## Overview

The `bootstrap.yml` playbook is the **first playbook you run** when setting up a new cluster. It establishes passwordless SSH access from your control node (workstation/WSL) to all cluster nodes, enabling all subsequent Ansible automation.

:::tip Run This First
Bootstrap must be completed before running any other playbooks. All other automation depends on passwordless SSH being configured.
:::

## What Bootstrap Does

1. **Checks for SSH Key on Control Node**
   - Looks for existing `~/.ssh/id_ed25519` key
   - If not found, generates a new ED25519 key pair
   - Uses ED25519 for better security and performance

2. **Prompts for Cluster Password**
   - Asks for the SSH password to access cluster nodes
   - Only needed this one time during bootstrap
   - Password is not stored anywhere

3. **Distributes SSH Public Key**
   - Copies your public key to each node's `~/.ssh/authorized_keys`
   - Uses the password you provided for initial authentication
   - Configures proper permissions automatically

4. **Verifies Passwordless SSH**
   - Tests connection to each node without password
   - Confirms keys are properly configured
   - Reports any failures

5. **Shows Completion Summary**
   - Displays number of nodes configured
   - Suggests next steps in the deployment

## Prerequisites

### Control Node (Your Workstation/WSL)

- ✅ Ansible installed
- ✅ Network connectivity to all cluster nodes
- ✅ SSH client installed (usually pre-installed)

### Cluster Nodes

- ✅ Ubuntu Server 24.04 LTS installed
- ✅ SSH server running (OpenSSH)
- ✅ User account created (same username on all nodes recommended)
- ✅ User has sudo privileges
- ✅ Password authentication enabled **temporarily** (will disable after bootstrap for security)

## Usage

### Basic Bootstrap

```bash
cd ~/arclink/ansible
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

**When prompted, enter the SSH password for your cluster nodes:**
- This is the password for the `ansible_user` account on the nodes
- Same password must work on ALL nodes
- Type carefully - password entry is hidden
- This password is only needed this ONE time

**Workflow:**
1. Prompts for cluster node password (enter carefully!)
2. Generates or uses existing SSH key
3. Distributes key to all nodes in inventory
4. Tests passwordless SSH
5. Shows completion summary

:::tip Password Entry
The password prompt shows: `Enter the password for cluster nodes:`
- Password is hidden as you type (no characters appear)
- Press Enter when done
- If you mistype, the playbook will fail - just run it again
:::

### Verify Bootstrap Success (Optional)

The next playbook (`disable-password-auth.yml`) automatically verifies SSH keys work before disabling password authentication. However, you can manually check if needed:

```bash
ansible all -i inventory/production.yml -m ping
```

**Expected output for each node:**
```
node0.research.core | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
node1.research.core | SUCCESS => ...
node2.research.core | SUCCESS => ...
```

**If ANY node shows `UNREACHABLE` or `FAILED`:**

```bash
# Option 1: Re-run bootstrap for specific failed node(s)
ansible-playbook playbooks/bootstrap.yml --ask-pass --limit node1.research.core

# Option 2: Re-run bootstrap for all nodes
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

:::tip Automatic Protection
The `disable-password-auth.yml` playbook includes automatic verification and will fail safely with clear instructions if SSH keys aren't working on all nodes.
:::

### Expected Output

```
Enter the password for cluster nodes: ********

PLAY [Bootstrap SSH Access to Cluster Nodes] ******************************

TASK [Check if SSH key exists] *********************************************
ok: [localhost]

TASK [Generate SSH key if it doesn't exist] ********************************
skipped: [localhost]

TASK [Display SSH key location] ********************************************
ok: [localhost] => {
    "msg": "SSH key located at: /home/user/.ssh/id_ed25519"
}

PLAY [Distribute SSH Keys to All Nodes] ************************************

TASK [Test SSH connection] *************************************************
ok: [node0.research.core]
ok: [node1.research.core]
...

TASK [Verify passwordless SSH] *********************************************
ok: [node0.research.core]
ok: [node1.research.core]
...

PLAY RECAP *****************************************************************
node0.research.core        : ok=3    changed=1    failed=0
node1.research.core        : ok=3    changed=1    failed=0
```

## Configuration

### Inventory File

Ensure your `inventory/production.yml` is configured:

```yaml
all:
  vars:
    ansible_user: yourusername  # Must match user on cluster nodes
    ansible_become: yes
  
  children:
    k3s_cluster:
      children:
        k3s_master:
          hosts:
            node0:
              ansible_host: 192.168.1.100
        k3s_agents:
          hosts:
            node1:
              ansible_host: 192.168.1.101
```

**Important:** The `ansible_user` must be the same user account that exists on all cluster nodes.

## SSH Key Details

### Key Type: ED25519

The bootstrap playbook uses ED25519 keys for:
- ✅ Better security than RSA
- ✅ Smaller key size (more efficient)
- ✅ Faster key generation and verification
- ✅ Modern cryptographic standard

### Key Location

- **Private key:** `~/.ssh/id_ed25519`
- **Public key:** `~/.ssh/id_ed25519.pub`

### Key Permissions

The playbook automatically sets correct permissions:
- Private key: `600` (read/write for owner only)
- Public key: `644` (readable by all)

## Troubleshooting

### Password Authentication Failed

**Error:** `Invalid/incorrect password` or `Permission denied (publickey,password)`

This is the most common bootstrap error! Usually caused by:

**1. Wrong password entered**
   - The password prompt is invisible - easy to mistype
   - Try running bootstrap again and type carefully
   - Verify password works manually first:
     ```bash
     ssh ansible_user@node0
     # If this works, the password is correct
     ```

**2. Password doesn't work on all nodes**
   - All nodes must have the SAME password for `ansible_user`
   - Test each node:
     ```bash
     ssh ansible_user@node0  # Should work
     ssh ansible_user@node1  # Should work
     ssh ansible_user@node2  # Should work
     ```
   - If different, set same password on all nodes

**3. Password authentication disabled**
   - Check SSH service is running:
     ```bash
     ssh ansible_user@node0 'sudo systemctl status ssh'
     ```
   - Ensure password auth is enabled in `/etc/ssh/sshd_config`:
     ```bash
     PasswordAuthentication yes
     ```
   - Restart SSH if you changed it:
     ```bash
     sudo systemctl restart ssh
     ```

**Quick fix:** Just run bootstrap again with the correct password:
```bash
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

### SSH Key Already Exists

If you already have an SSH key, the playbook will use it. To generate a new key:

```bash
# Backup existing key
mv ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.backup
mv ~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub.backup

# Run bootstrap again
ansible-playbook playbooks/bootstrap.yml --ask-pass
```

### Connection Timeout

**Error:** `Failed to connect to the host via ssh: Connection timed out`

**Solutions:**
1. Verify network connectivity:
   ```bash
   ping node0
   ```
2. Check firewall rules allow SSH (port 22)
3. Verify IP addresses in inventory are correct

### User Does Not Exist

**Error:** `User yourusername does not exist`

**Solution:** Create the user on all nodes first:
```bash
# On each cluster node
sudo adduser yourusername
sudo usermod -aG sudo yourusername
```

## Post-Bootstrap

After bootstrap completes successfully:

### Test Passwordless SSH

```bash
# Test from control node
ssh node0
# Should connect without password prompt
```

### Verify Ansible Connectivity

```bash
cd ~/arclink/ansible
ansible -i inventory/production.yml all -m ping
```

**Expected output:**
```
node0.research.core | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
node1.research.core | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 🔒 Disable Password Authentication (Recommended)

**IMPORTANT:** Now that SSH keys are set up, disable password authentication for security:

```bash
# Disable password authentication on all nodes
cd ~/arclink/ansible
ansible -i inventory/production.yml all -m lineinfile -b \
  -a "path=/etc/ssh/sshd_config regexp='^PasswordAuthentication' line='PasswordAuthentication no'"

# Restart SSH service to apply changes
ansible -i inventory/production.yml all -m systemd -b \
  -a "name=ssh state=restarted"
```

**What this does:**
- Disables password-based SSH login on all cluster nodes
- Only SSH key authentication will work
- Significantly improves security (prevents brute-force attacks)
- Keys cannot be stolen like passwords

**Verify it worked:**
```bash
# Try to SSH with password (should fail)
ssh -o PubkeyAuthentication=no node0
# Should see: Permission denied (publickey)

# SSH with keys still works
ssh node0
# Should connect successfully
```

:::warning
After disabling password authentication, you MUST use SSH keys. Don't lose your private key (`~/.ssh/id_ed25519`)!
:::

### Next Steps

1. **Run prerequisite validation:**
   ```bash
   ansible-playbook playbooks/validate-prerequisites.yml
   ```

2. **Setup common configuration:**
   ```bash
   ansible-playbook playbooks/setup-common.yml
   ```

3. **Continue with deployment:**
   - See [Quick Start Guide](../quickstart.md)
   - See [Complete Deployment Guide](../complete-deployment.md)

## Re-running Bootstrap

### When to Re-run

- ✅ After reinstalling cluster nodes
- ✅ When adding new nodes to inventory
- ✅ If SSH keys are lost or corrupted
- ✅ After rotating SSH keys for security

### Safe to Re-run

Yes! Bootstrap is idempotent and safe to run multiple times:
- Won't overwrite existing SSH keys (unless deleted)
- Won't break existing passwordless SSH
- Will only add keys to nodes that need them

## Security Considerations

### Disable Password Authentication (Critical!)

**⚠️ This is a critical security step!** After bootstrap completes, you MUST disable password authentication:

**Why this matters:**
- Password authentication is vulnerable to brute-force attacks
- Attackers constantly scan for SSH servers accepting passwords
- Key-based auth is significantly more secure
- This is a best practice for all production systems

**Quick method (using Ansible):**
```bash
cd ~/arclink/ansible

# Disable password authentication on all nodes
ansible -i inventory/production.yml all -m lineinfile -b \
  -a "path=/etc/ssh/sshd_config regexp='^PasswordAuthentication' line='PasswordAuthentication no'"

# Restart SSH service
ansible -i inventory/production.yml all -m systemd -b -a "name=ssh state=restarted"
```

**Manual method (per node):**
```bash
# On each cluster node
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart ssh
```

**Verify password auth is disabled:**
```bash
# Should fail with "Permission denied (publickey)"
ssh -o PubkeyAuthentication=no node0
```

:::danger Production Requirement
Never leave password authentication enabled on production systems. This is a critical security vulnerability.
:::

### Key Management

- ✅ Keep your private key (`~/.ssh/id_ed25519`) secure
- ✅ Never share or commit your private key
- ✅ Back up your private key to a secure location
- ✅ Use a passphrase for additional security (optional)

### Multi-User Environments

Each team member should:
1. Run bootstrap with their own SSH key
2. Have their own user account on cluster nodes
3. Not share SSH keys or passwords

## Advanced Usage

### Using Existing SSH Keys

If you prefer to use a different key:

1. Generate your preferred key type:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```

2. Manually copy to nodes:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub user@node0
   ```

3. Skip bootstrap and proceed to `setup-common.yml`

### Custom SSH Key Path

Modify the playbook to use a custom key location:

```bash
# Edit playbooks/bootstrap.yml
# Change: ~/.ssh/id_ed25519
# To: ~/.ssh/custom_key
```

## Summary

Bootstrap is the critical first step that enables all automation:

| What | How | Why |
|------|-----|-----|
| **SSH Keys** | Generates ED25519 key pair | Secure, passwordless authentication |
| **Key Distribution** | Copies public key to all nodes | Enables Ansible automation |
| **Verification** | Tests passwordless SSH | Ensures setup is correct |
| **One-Time Setup** | Run once per cluster | All other playbooks depend on this |

After successful bootstrap, you're ready to deploy your cluster! 🚀
