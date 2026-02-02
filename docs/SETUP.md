# Setup Guide

Complete deployment walkthrough for docker-ai infrastructure.

## Prerequisites

- Ansible 2.16+
- Docker VM ready (Debian/Ubuntu)
- Cloudflare account + API token
- SMB share for media storage
- Vault password file (`.vault_pass`)

## Initial Server Prep

**1. Inventory setup:**
```bash
# Edit inventory
vim ai-ansible/inventory.ini

# Add target host
[docker_hosts]
docker01.ota.lan ansible_host=10.0.0.80 ansible_user=stanley
```

**2. SSH access:**
```bash
# Copy SSH key
ssh-copy-id stanley@docker01.ota.lan

# Test connection
ansible -i ai-ansible/inventory.ini docker_hosts -m ping
```

## Vault Configuration

**3. Configure secrets:**
```bash
# Decrypt vault
ansible-vault decrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Edit required secrets:
# - vault_cloudflare_api_token
# - vault_smb_username/password
# - vault_traefik_cert_email
# - vault_ip_* (if IPs changed)

# Re-encrypt
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

## Environment File

**4. Create .env file:**
```bash
cp input/.env.example input/.env
vim input/.env

# Configure:
# - PUID/PGID
# - TIMEZONE
# - FOLDER_FOR_DATA
# - Ports
```

## First Deployment

**5. Install pre-commit hook:**
```bash
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**6. Run full deployment:**
```bash
# Bootstrap + Docker + Proxy + Containers
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/site.yml \
  --vault-password-file=.vault_pass
```

**Phase-by-phase alternative:**
```bash
# 1. Bootstrap (OS hardening, users)
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/bootstrap.yml \
  --vault-password-file=.vault_pass

# 2. Docker engine
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/docker.yml \
  --vault-password-file=.vault_pass

# 3. Traefik proxy
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/proxy.yml \
  --vault-password-file=.vault_pass

# 4. All containers
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/containers.yml \
  --vault-password-file=.vault_pass
```

## Post-Deployment Validation

**7. Verify services:**
```bash
# SSH to host
ssh stanley@docker01.ota.lan

# Check Docker
docker ps
docker network ls

# Check Traefik
curl -k https://localhost:443

# Check logs
tail -f /docker/logs/traefik/access.log
```

**8. Access services:**
- Traefik: https://traefik.silentijsje.com
- Portainer: https://portainer.silentijsje.com
- Homepage: https://home.silentijsje.com

**9. DNS verification:**
```bash
# Check Cloudflare DNS records created
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
  -H "Authorization: Bearer ${CF_TOKEN}"
```

## Troubleshooting

**Container won't start:**
```bash
docker logs <container_name>
docker inspect <container_name>
```

**Traefik routing issues:**
```bash
# Check Traefik config
cat /docker/traefik/traefik.yaml
cat /docker/traefik/internal.yaml
cat /docker/traefik/dynamic.yaml

# Restart Traefik
docker restart traefik
```

**Mount issues:**
```bash
# Check SMB mount
mount | grep cifs
df -h | grep media
```

## Updates

**Re-deploy specific role:**
```bash
# Update containers only
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/containers.yml \
  --vault-password-file=.vault_pass \
  --tags=radarr  # Optional: specific service
```
