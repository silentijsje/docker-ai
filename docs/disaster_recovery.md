# Disaster Recovery: API Token & Secret Rotation

Use this runbook when you've been compromised or need to rotate all credentials.

---

## 1. Triage

1. **Assess scope** — determine if this is a targeted breach (rotate affected service only) or full compromise (rotate everything below)
2. **Revoke GitHub PATs immediately** — limits attacker pivot to other services via CI/CD
3. **Take servers offline** if actively being exploited — stop the bleeding before rotating
4. **Check audit logs** in Authentik, Cloudflare, and Proxmox to understand what was accessed

---

## 2. Prerequisites

Before starting rotation:

- [ ] Vault password available (stored off-repo)
- [ ] Ansible working: `ansible --version`
- [ ] SSH access to all servers: `ansible all -m ping`
- [ ] Pre-commit hook installed: `cp scripts/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`

---

## 3. Decrypt Vault

```bash
scripts/vault decrypt
# Verify: head -1 ansible/vars/vault.yml  → should NOT start with $ANSIBLE_VAULT
```

> **WARNING: Never commit with vault decrypted. Re-encrypt before every commit (Step 7).**

---

## 4. Secret Rotation Checklist

Rotate in this order — infrastructure first, then apps.

### Critical Infrastructure

| Service | Where to Rotate | Vault Variable | Extra Steps |
|---|---|---|---|
| **Cloudflare DNS** | dash.cloudflare.com → My Profile → API Tokens | `vault_cloudflare_api_token`, `vault_cloudflare_zone_id` | Revoke old token before creating new one |
| **Proxmox node 1** | UI → Datacenter → Permissions → API Tokens | `vault_proxmox_*` | Delete old token, create new |
| **Proxmox node 2** | Same as above | `vault_proxmox_*` | |
| **Proxmox Backup Server** | Same as above | `vault_proxmox_*` | |
| **TrueNAS** | UI → Credentials → API Keys | `vault_truenas_api_key` | |
| **Authentik** | Admin → System → Settings → Secret Key | `vault_authentik_secret_key` | Requires full redeploy; invalidates all sessions |
| **LLDAP** | Regenerate JWT secret + key seed | `vault_lldap_jwt_secret`, `vault_lldap_key_seed` | Also hardcoded in `org-compose/ldap/docker-compose.ldap.yml` — update manually |
| **Vaultwarden** | Generate new token, hash with argon2 | `vault_vaultwarden_admin_token` | Use `echo -n "token" \| argon2 ...` |

### Network & Security

| Service | Where to Rotate | Vault Variable | Extra Steps |
|---|---|---|---|
| **CrowdSec** | app.crowdsec.net → Security Engines | `vault_crowdsec_lapi_key`, `vault_crowdsec_enrollment_key` | Re-enroll bouncer after rotation |
| **Tailscale/Newt** | admin.tailscale.com → Settings → Keys | hardcoded in `org-compose/newt/docker-compose.newt.yml` | Update `NEWT_SECRET` in that file directly |
| **UFW rules** | Edit `ansible/vars/ufw-vault.yml` | — | Re-encrypt after: `scripts/vault encrypt` |

### Media Stack

| Service | Where to Rotate | Vault Variable |
|---|---|---|
| **Plex** | plex.tv → Account → Authorized Devices → get new token | `vault_plex_token` |
| **Jellyfin (instance 1)** | UI → Admin → API Keys → Add Key | `vault_jellyfin_*` |
| **Jellyfin (instance 2)** | Same as above | `vault_jellyfin_*` |
| **Radarr** | Settings → General → Security → Regenerate | `vault_radarr_api_key` |
| **Sonarr** | Settings → General → Security → Regenerate | `vault_sonarr_api_key` |
| **Overseerr** | Settings → General → Regenerate API Key | `vault_overseerr_api_key` |
| **SABnzbd** | Config → General → API Key → Generate | `vault_sabnzbd_api_key` |
| **Tautulli** | Settings → Web Interface → Regenerate API Key | `vault_tautulli_api_key` |
| **Prowlarr** | Settings → General → Security → Regenerate | `vault_prowlarr_api_key` |

### Apps & Services

| Service | Where to Rotate | Vault Variable | Extra Steps |
|---|---|---|---|
| **Home Assistant** | Profile → Long-Lived Access Tokens → Create | `vault_homeassistant_token` | Delete old token first |
| **Immich** | Account Settings → API Keys | `vault_immich_api_key` | |
| **Paperless** | Admin → Auth Tokens | `vault_paperless_api_key` | |
| **Mealie** | Admin → Manage Users → API Keys | `vault_mealie_*` | OIDC client secret also hardcoded in `org-compose/mealie/docker-compose.mealie.yml` |
| **Grafana** | Admin → Service Accounts → Rotate | `vault_grafana_*` | |
| **Portainer** | Account → Access Tokens → Add Token | `vault_portainer_api_key` | |
| **Technitium DNS (instance 1)** | Admin → API Token | `vault_technitium_*` | |
| **Technitium DNS (instance 2)** | Same as above | `vault_technitium_*` | |
| **Jellystat** | Regenerate JWT secret | hardcoded in `org-compose/jellystat/docker-compose.jellystat.yml` | Update `POSTGRE_JWT_SECRET` in that file directly |

### External APIs

| Service | Where to Rotate | Vault Variable |
|---|---|---|
| **OpenAI** | platform.openai.com → API Keys | `vault_openai_api_key` (in mealie env) |
| **SMTP/Fastmail** | Fastmail Settings → Passwords → App Passwords | `vault_smtp_*` |

---

## 5. Update Vault Files

Edit the vault files with new values from Step 4:

```bash
$EDITOR ansible/vars/vault.yml       # main secrets
$EDITOR ansible/vars/ufw-vault.yml   # firewall config
$EDITOR ansible/vars/prod-vault.yml  # prod environment
```

---

## 6. Update Hardcoded Secrets

Four docker-compose files have secrets that are **not** in the vault. Edit these directly:

```bash
$EDITOR org-compose/ldap/docker-compose.ldap.yml       # JWT_SECRET, KEY_SEED
$EDITOR org-compose/newt/docker-compose.newt.yml       # NEWT_SECRET
$EDITOR org-compose/jellystat/docker-compose.jellystat.yml  # POSTGRE_JWT_SECRET
$EDITOR org-compose/mealie/docker-compose.mealie.yml   # OIDC_CLIENT_SECRET
```

---

## 7. Re-encrypt Vault

```bash
scripts/vault encrypt
# Verify: head -1 ansible/vars/vault.yml  → must show: $ANSIBLE_VAULT;1.1;AES256
```

---

## 8. Redeploy

```bash
ansible-playbook ansible/playbooks/deploy.yml
```

---

## 9. Verification

- [ ] Homepage dashboard widgets show live data (exercises all API keys)
- [ ] Traefik dashboard shows active routes
- [ ] Authentik login works
- [ ] CrowdSec bouncer connected: check Traefik logs for crowdsec middleware
- [ ] `ansible-playbook ansible/playbooks/deploy.yml --check` shows no drift

---

## 10. Secrets Debt (Fix After Recovery)

The following are security gaps to address once the immediate incident is resolved:

- **Move hardcoded secrets to vault** — the 4 files in Step 6 should use Jinja2 templates like other services
- **Audit `.env` files** — `org-compose/*/.*env` files contain plaintext credentials; ensure they are in `.gitignore` and not in git history
- **Rotate vault password** — if the `.vault_pass` file itself was compromised, change the vault password: `ansible-vault rekey ansible/vars/vault.yml`
