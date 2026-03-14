# Infrastructure Analysis & Recommendations

## Context
Full audit of the docker-ai Ansible IaC repo — media stack, proxy, security, automation. Goal: identify gaps, improvements, and next steps.

---

## Current State Summary

**What you have:**
- 5 Ansible roles (bootstrap, docker, proxy, containers, ssh_containers)
- 4 playbooks (setup, containers, proxy, update)
- Traefik + CrowdSec reverse proxy with TLS 1.2+, HSTS, IP allowlists
- Media stack (*arr suite, qBittorrent, SABnzbd, Jellyfin, Plex)
- Authentik SSO, Booklore, Homepage, Portainer, Watchtower
- SSH hardening, vault-encrypted secrets, Gitleaks config
- Proxmox VE/PBS for VM management, TrueNAS for storage
- 2 networks: prod (10.0.30.x) and OTA (10.0.40.x)

---

## 1. Security Improvements

### 1a. HIGH: Implement GitHub Actions CI/CD (mentioned in README but missing)
- `scripts/pre-commit` dir referenced but doesn't exist
- No `.github/workflows/` — linting, vault checks, molecule tests aren't automated
- **Action:** Create `.github/workflows/ci.yml` with:
  - `ansible-lint` on all playbooks
  - `yamllint` validation
  - Gitleaks secret scan
  - Vault encryption check (`head -1 ansible/vars/vault.yml`)
  - Molecule tests for each role

### 1b. HIGH: Add fail2ban or CrowdSec on host level
- CrowdSec runs inside Docker protecting Traefik, but the host SSH is unprotected against brute-force
- **Action:** Add a `security` role or extend `bootstrap` to install CrowdSec agent on host (watches sshd logs, integrates with same LAPI)

### 1c. MEDIUM: Docker socket protection
- Traefik and Portainer mount `/var/run/docker.sock` read-write — full root-equivalent access
- **Action:** Deploy a Docker socket proxy (like `tecnativa/docker-socket-proxy`) and point Traefik/Portainer at it with restricted API access

### 1d. MEDIUM: Container read-only filesystems
- None of the containers use `read_only: true` or `security_opt: [no-new-privileges:true]`
- **Action:** Add `security_opt: [no-new-privileges:true]` to all compose templates; add `read_only: true` where feasible (Traefik, Homepage, *arr apps)

### 1e. MEDIUM: Rate limiting on Traefik
- No rate-limiting middleware configured — any public endpoint can be hammered
- **Action:** Add a `rateLimit` middleware (e.g., 100 req/s average, 200 burst) on public-facing routes (Overseerr, Jellyfin, Wizarr)

### 1f. LOW: Network segmentation for containers
- All containers share `mediastack` network — a compromised container can reach all others
- **Action:** Split into purpose-specific networks (media, infra, auth, downloads) with only Traefik bridging them

---

## 2. Workflow Improvements

### 2a. HIGH: Create a `site.yml` master playbook
- Currently 4 separate playbooks; no single entry point
- README references `site.yml` but it doesn't exist
- **Action:** Create `site.yml` that imports setup, proxy, containers in order

### 2b. HIGH: Automate backup scripts
- BACKUP.md has great documentation but all scripts are manual/copy-paste
- No actual backup cron or Ansible role
- **Action:** Create a `backup` role that:
  - Deploys the Docker data backup script
  - Configures cron jobs
  - Sets up DB dump scripts for MariaDB/PostgreSQL
  - Sends notifications on failure via Notifiarr

### 2c. MEDIUM: Add tags to playbooks
- Can't selectively run parts of a playbook (e.g., just update Radarr without touching everything)
- **Action:** Add Ansible tags per service/phase: `tags: [radarr, media, phase2]`

### 2d. MEDIUM: Makefile for common operations
- No Makefile — common commands are manual
- **Action:** Create Makefile with targets: `lint`, `test`, `deploy`, `deploy-proxy`, `deploy-containers`, `vault-edit`, `vault-check`, `backup`

### 2e. LOW: Consolidate enabled_containers logic
- `enabled_containers` dict in docker-vars.yml controls deployment, but each service has its own `when:` check
- **Action:** Use a loop over `enabled_containers` where possible to reduce template repetition

---

## 3. Monitoring & Observability (biggest gap)

### 3a. HIGH: Deploy a monitoring stack
- Prometheus metrics are exposed (Traefik :8082, CrowdSec :6060) but nothing scrapes them
- No alerting, no dashboards, no visibility into service health
- **Action:** Add a `monitoring` role deploying:
  - **Prometheus** — scrape Traefik, CrowdSec, node-exporter
  - **Grafana** — dashboards for traffic, security events, system resources
  - **node-exporter** — host metrics (CPU, RAM, disk, network)
  - **cAdvisor** — container-level metrics
  - Route through Traefik at `grafana.silentijsje.com`

### 3b. HIGH: Centralized logging
- Only Traefik access logs exist; no container log aggregation
- **Action:** Deploy **Loki + Promtail** (lightweight, integrates with Grafana):
  - Promtail collects Docker container logs
  - Loki stores and indexes
  - Query logs from Grafana

### 3c. MEDIUM: Uptime monitoring
- No way to know if a service goes down until you notice manually
- **Action:** Deploy **Uptime Kuma** (self-hosted):
  - HTTP checks for all services
  - Notifications via Notifiarr/Discord/email
  - Status page at `status.silentijsje.com`

### 3d. MEDIUM: Health checks on all containers
- Only Booklore's MariaDB has a health check; no other container does
- **Action:** Add `healthcheck` to all compose templates (HTTP check on each service's web port)

---

## 4. Applications to Consider

| App | Purpose |
|-----|---------|
| **Uptime Kuma** | Service monitoring / status page |
| **Gluetun** | VPN container for torrent traffic (qBittorrent routes through it) |
| **Recyclarr** | Auto-sync TRaSH Guides quality profiles to Radarr/Sonarr |
| **Flaresolverr** | Cloudflare challenge solver for Prowlarr indexers |
| **Tdarr** | Automated media transcoding (reduce storage, normalize codecs) |
| **Homarr / Dashy** | More feature-rich dashboard alternative to Homepage |
| **Scrutiny** | Hard drive S.M.A.R.T. monitoring (TrueNAS health) |
| **Dozzle** | Real-time Docker log viewer (lightweight, quick debugging) |
| **Vaultwarden** | Self-hosted Bitwarden password manager |

---

## 5. Suggested Next Steps (Priority Order)

1. **Create CI/CD pipeline** — `.github/workflows/ci.yml` (prevents regressions)
2. **Deploy monitoring stack** — Prometheus + Grafana + node-exporter (visibility)
3. **Deploy Uptime Kuma** — immediate service health alerts
4. **Create `site.yml`** — single deployment entry point
5. **Automate backups** — backup role with cron + notifications
6. **Add host-level CrowdSec** — SSH brute-force protection
7. **Docker socket proxy** — reduce attack surface
8. **Add Gluetun VPN** — protect torrent traffic
9. **Add Recyclarr** — automate quality profiles
10. **Add container health checks** — across all services

---

## Unresolved Questions

- Exposing any services publicly beyond LAN? (affects rate limiting/WAF priority)
- Authentik SSO actually deployed or just templated? (referenced but no container role)
- VPN for torrent traffic desired? (legal/privacy consideration)
- Notification preference? (Discord, email, Telegram, Notifiarr)
- Budget for offsite backup? (cloud storage for 3-2-1 backup strategy)
- Prowlarr deployed separately or missing from roles? (in architecture doc but not in container templates)
