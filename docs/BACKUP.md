# Backup & Restore Guide

Data protection strategies.

## What to Backup

### Critical Data
**1. Vault secrets:**
- `ai-ansible/vars/vault.yml` (encrypted)
- `.vault_pass` (KEEP SECURE - offline storage)

**2. Docker data:**
- `/docker/` - All service configs + databases
- Key directories:
  - `/docker/traefik/` (configs, certs)
  - `/docker/authentik/` (identity data)
  - `/docker/portainer/` (container configs)
  - `/docker/*/` (all service data)

**3. Media library:**
- `/mnt/media/` (or SMB source: `//10.0.40.2/media`)

**4. Git repository:**
- All playbooks, roles, configs
- Already backed up via GitHub

### Non-critical (Recreatable)
- Docker images (re-pull from registry)
- Logs (can be discarded)
- Temp files

## Backup Strategies

### 1. Proxmox Backup Server (PBS)

**VM snapshots:**
```bash
# Snapshot entire docker01 VM
pvesh create /nodes/pve1/qemu/101/snapshot --snapname backup-$(date +%Y%m%d)

# Backup to PBS
vzdump 101 --storage pbs --mode snapshot
```

**Scheduled backups:**
- Proxmox VE → Datacenter → Backup → Add
- Schedule: Daily at 2 AM
- Target: Proxmox Backup Server (10.0.0.75)
- Mode: Snapshot
- Retention: 7 daily, 4 weekly, 3 monthly

### 2. Docker Data Backup

**Manual backup script:**
```bash
#!/bin/bash
# backup-docker.sh

BACKUP_DIR="/mnt/backups/docker"
DATE=$(date +%Y%m%d-%H%M%S)

# Stop containers (optional - for consistency)
cd /opt/docker-ai/input/docker
docker compose down

# Backup
tar -czf "${BACKUP_DIR}/docker-data-${DATE}.tar.gz" /docker/

# Restart
docker compose up -d

# Cleanup old backups (keep 30 days)
find "${BACKUP_DIR}" -name "docker-data-*.tar.gz" -mtime +30 -delete
```

**Automated with cron:**
```bash
# Edit crontab
crontab -e

# Add daily backup at 3 AM
0 3 * * * /opt/scripts/backup-docker.sh >> /var/log/docker-backup.log 2>&1
```

### 3. Database Backups

**PostgreSQL backup:**
```bash
#!/bin/bash
# backup-databases.sh

BACKUP_DIR="/mnt/backups/databases"
DATE=$(date +%Y%m%d-%H%M%S)

# Authentik database
docker exec postgresql pg_dump -U authentik authentik > \
  "${BACKUP_DIR}/authentik-${DATE}.sql"

# Paperless database
docker exec paperless-db pg_dump -U paperless paperless > \
  "${BACKUP_DIR}/paperless-${DATE}.sql"

# Compress
gzip "${BACKUP_DIR}"/*-${DATE}.sql

# Cleanup (keep 14 days)
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +14 -delete
```

**MariaDB backup (Booklore):**
```bash
docker exec booklore-db mysqldump -u booklore -p booklore > \
  /mnt/backups/databases/booklore-$(date +%Y%m%d).sql
```

### 4. TrueNAS Backups

**SMB share backup:**
- TrueNAS handles replication/snapshots
- Check TrueNAS → Storage → Snapshots
- Schedule: Hourly snapshots, 24h retention
- Daily snapshots, 30d retention
- Weekly snapshots, 3 months retention

**Offsite replication:**
- TrueNAS → Tasks → Replication
- Target: Cloud provider or remote TrueNAS
- Encrypted replication recommended

### 5. Configuration Backup

**Git repository:**
```bash
# Already backed up to GitHub
git remote -v
# origin: https://github.com/silentijsje/docker-ai.git

# Ensure all committed
git status

# Push
git push origin main
```

**Vault password:**
```bash
# Store .vault_pass securely:
# - Password manager (1Password, Bitwarden)
# - Offline USB drive
# - Printed copy in safe

# NEVER commit .vault_pass to Git!
```

## Restore Procedures

### 1. Full System Restore

**From Proxmox Backup:**
```bash
# Restore VM from PBS
qmrestore pbs:backup/vm-101-<timestamp> 101 --storage local-lvm

# Start VM
qm start 101

# Verify
ssh stanley@docker01.ota.lan
docker ps
```

### 2. Docker Data Restore

```bash
# Stop containers
cd /opt/docker-ai/input/docker
docker compose down

# Restore from backup
cd /
tar -xzf /mnt/backups/docker/docker-data-YYYYMMDD-HHMMSS.tar.gz

# Restart containers
cd /opt/docker-ai
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/containers.yml \
  --vault-password-file=.vault_pass
```

### 3. Database Restore

**PostgreSQL:**
```bash
# Restore Authentik DB
gunzip < /mnt/backups/databases/authentik-YYYYMMDD-HHMMSS.sql.gz | \
  docker exec -i postgresql psql -U authentik authentik

# Restart service
docker restart authentik-server
```

**MariaDB:**
```bash
# Restore Booklore DB
docker exec -i booklore-db mysql -u booklore -p booklore < \
  /mnt/backups/databases/booklore-YYYYMMDD.sql
```

### 4. Vault Restore

**From encrypted backup:**
```bash
# Restore vault file
cp /mnt/backups/vault/vault.yml.backup ai-ansible/vars/vault.yml

# Restore vault password
# (retrieve from password manager/offline storage)
echo "password" > .vault_pass
chmod 600 .vault_pass

# Verify
ansible-vault view ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

### 5. Config-only Restore

**Fresh deployment from Git:**
```bash
# Clone repository
git clone https://github.com/silentijsje/docker-ai.git
cd docker-ai

# Restore .vault_pass
echo "password" > .vault_pass
chmod 600 .vault_pass

# Deploy
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/site.yml \
  --vault-password-file=.vault_pass
```

## Backup Verification

**Test restore quarterly:**
```bash
# 1. Spin up test VM
# 2. Restore latest backup
# 3. Verify services start
# 4. Check data integrity
# 5. Document any issues
```

**Checklist:**
- [ ] VM boots successfully
- [ ] Docker services start
- [ ] Databases accessible
- [ ] Data intact (spot check)
- [ ] Traefik routing works
- [ ] Authentication works

## Disaster Recovery

**RPO (Recovery Point Objective):** 24 hours
- Daily VM snapshots
- Hourly TrueNAS snapshots for media

**RTO (Recovery Time Objective):** 4 hours
- VM restore: ~1 hour
- Service startup: ~30 min
- Verification: ~2 hours

**Recovery steps:**
1. Restore VM from PBS (1h)
2. Verify boot and network (15m)
3. Check Docker services (15m)
4. Restore any missing data (30m)
5. Verify all services accessible (1h)
6. Update DNS if IP changed (30m)

## Backup Storage

**Primary:** Proxmox Backup Server (10.0.0.75)
**Secondary:** TrueNAS snapshots/replication
**Offsite:** Cloud backup (optional)

**Retention policy:**
- Hourly snapshots: 24 hours
- Daily backups: 30 days
- Weekly backups: 3 months
- Monthly backups: 1 year

## Monitoring Backup Health

**Check backup status:**
```bash
# PBS backup list
pvesh get /nodes/pbs/storage/pbs/content --type backup

# Check last backup date
find /mnt/backups -name "docker-data-*.tar.gz" -mtime -1

# Verify backup size (should be consistent)
ls -lh /mnt/backups/docker/docker-data-*.tar.gz | tail -5
```

**Alert on backup failure:**
- Monitor backup job logs
- Set up notifications (email/Notifiarr)
- Weekly manual verification

## Important Notes

- **Test restores regularly** - Backups are useless if restores fail
- **Keep .vault_pass secure** - Can't decrypt secrets without it
- **Document changes** - Update this doc if backup strategy changes
- **Offsite copy recommended** - For true disaster recovery
