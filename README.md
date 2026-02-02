# docker-ai

Ansible-based IaC for media management & hosting ecosystem on Docker.

## Architecture

**Target:** Single VM `docker01.ota.lan` (.ota.lan private network)

**Stack:**
- Ansible automation (roles: bootstrap, docker, proxy, containers)
- Docker Compose with 20+ services
- Traefik reverse proxy + Cloudflare TLS
- CrowdSec WAF
- Authentik identity provider

## Services

**Media Management:** Radarr, Sonarr, Whisparr, Prowlarr, Tautulli
**Requests:** Overseerr, Huntarr, Wizarr
**Storage:** Nextcloud, Immich, Paperless, Mealie
**Infrastructure:** Portainer, Homepage, Pi-hole DNS, DDNS Updater, Notifiarr

## Quick Start

```bash
# Install pre-commit hook (blocks unencrypted vault commits)
cp scripts/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# Run full deployment
ansible-playbook -i ai-ansible/inventory.ini ai-ansible/playbooks/site.yml --vault-password-file=.vault_pass

# Deploy specific roles
ansible-playbook -i ai-ansible/inventory.ini ai-ansible/playbooks/containers.yml --vault-password-file=.vault_pass
```

## Vault Management

**Check encryption:**
```bash
head -1 ai-ansible/vars/vault.yml  # Should show: $ANSIBLE_VAULT;1.1;AES256
```

**Edit secrets:**
```bash
ansible-vault decrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
# Edit file
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

## CI/CD

GitHub Actions pipeline:
- Vault encryption verification
- YAML/Ansible linting
- Secret scanning (Gitleaks)
- Molecule tests (all roles)
- Auto-runs on push/PR

## Requirements

- Ansible 2.16+
- Docker Engine + Compose v2
- Cloudflare DNS API token
- SMB share for persistent storage

## Directory Structure

```
ai-ansible/         # Playbooks & roles
input/docker/       # Compose service modules
roles/              # Molecule test scenarios
scripts/            # Pre-commit hook
```
