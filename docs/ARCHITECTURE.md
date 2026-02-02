# Architecture

Infrastructure design & component overview.

## Network Topology

```
Internet
    │
    ├─ Cloudflare DNS (TLS certs via DNS-01)
    │
    └─ Home Network (10.0.0.0/16)
         │
         ├─ Management VLAN (10.0.0.0/24)
         │   ├─ 10.0.0.1   - UniFi Controller
         │   ├─ 10.0.0.2   - TrueNAS
         │   ├─ 10.0.0.50  - Pi-hole DNS
         │   ├─ 10.0.0.70  - Proxmox VE 1
         │   ├─ 10.0.0.71  - Proxmox VE 2
         │   ├─ 10.0.0.75  - Proxmox Backup Server
         │   ├─ 10.0.0.80  - docker01 (main stack)
         │   ├─ 10.0.0.81  - Immich server
         │   ├─ 10.0.0.88  - NZBGet
         │   └─ 10.0.0.89  - qBittorrent
         │
         └─ Media VLAN (10.0.20.0/24)
             ├─ 10.0.20.10  - Jellyfin primary
             └─ 10.0.20.91  - Jellyfin secondary
```

## Layers

### Layer 1: Infrastructure (Ansible Roles)

```
bootstrap role
├─ OS hardening
├─ SSH config
├─ User management
├─ Timezone setup
└─ Base packages

docker role
├─ Docker Engine install
├─ Docker Compose v2
├─ Daemon config
└─ Network setup

proxy role
├─ Traefik deployment
├─ Static config
├─ Dynamic routing (templated)
└─ Internal routing (vault IPs)

containers role
├─ Phase 1: Infrastructure (Traefik, CrowdSec, Portainer, Homepage)
├─ Phase 2: Media managers (Radarr, Sonarr, Prowlarr, etc.)
├─ Phase 3: Request systems (Overseerr, Wizarr)
└─ Phase 4: Support services (Authentik, Nextcloud, etc.)
```

### Layer 2: Reverse Proxy (Traefik)

```
External Request
    │
    ├─ Port 80 (HTTP) ──────────► 443 redirect
    │
    └─ Port 443 (HTTPS/TLS)
         │
         ├─ Cloudflare DNS-01 Challenge
         │   └─ Auto TLS cert generation
         │
         ├─ CrowdSec WAF
         │   └─ Bot protection + IP filtering
         │
         ├─ Middlewares
         │   ├─ security-headers
         │   ├─ traefik-bouncer (CrowdSec)
         │   └─ ipAllowList (restricted services)
         │
         └─ Router Matching
             ├─ Host-based routing (*.silentijsje.com)
             ├─ Docker labels (auto-discovery)
             └─ File-based routing (internal.yaml)
```

### Layer 3: Container Stack

```
mediastack network
├─ Infrastructure
│   ├─ traefik (reverse proxy)
│   ├─ crowdsec (WAF)
│   ├─ portainer (Docker UI)
│   └─ homepage (dashboard)
│
├─ Media Management
│   ├─ radarr (movies)
│   ├─ sonarr (TV)
│   ├─ whisparr (XXX)
│   ├─ prowlarr (indexers)
│   └─ tautulli (Plex stats)
│
├─ Request Management
│   ├─ overseerr (requests)
│   ├─ huntarr (hunt requests)
│   └─ wizarr (user onboarding)
│
├─ Identity & Auth
│   ├─ authentik (SSO)
│   ├─ postgresql (authentik DB)
│   ├─ redis (authentik cache)
│   └─ ldap (directory)
│
└─ Storage & Services
    ├─ nextcloud (files)
    ├─ immich (photos)
    ├─ paperless (docs)
    ├─ mealie (recipes)
    ├─ booklore (books)
    └─ notifiarr (notifications)
```

## Data Flow

### Media Ingestion
```
User Request (Overseerr)
    ↓
Media Manager (Radarr/Sonarr)
    ↓
Indexer Search (Prowlarr)
    ↓
Download Client (qBT/NZB on separate hosts)
    ↓
SMB Share (TrueNAS: //10.0.40.2/media)
    ↓
CIFS Mount (/mnt/media on docker01)
    ↓
Jellyfin Playback
```

### Authentication Flow
```
User → Traefik
    ↓
Authentik SSO Check
    ↓
Service Access Granted
```

### Configuration Management
```
Git Repo
    ↓
Ansible Playbook
    ↓
Vault Decryption (runtime)
    ↓
Jinja2 Template Rendering
    ↓
File Deployment to Target
    ↓
Docker Compose Up
```

## Storage Architecture

```
docker01.ota.lan
├─ /docker (local SSD)
│   ├─ traefik/          (configs, certs, logs)
│   ├─ crowdsec/         (collections, decisions)
│   ├─ portainer/        (data)
│   ├─ authentik/        (media)
│   └─ {service}/        (app data)
│
└─ /mnt/media (SMB mount from TrueNAS)
    ├─ movies/
    ├─ tv/
    ├─ photos/
    └─ documents/
```

## High Availability Considerations

Current: Single VM deployment
- Traefik on docker01
- All services on docker01
- External dependencies: Jellyfin (separate hosts), qBT, NZB

Future scaling options:
- Docker Swarm mode
- Multiple proxy nodes
- Distributed storage (GlusterFS/Ceph)
- Database HA (PostgreSQL replication)

## Security Boundaries

```
Internet
    │
    ├─ Cloudflare (DDoS protection)
    │
    ├─ Traefik TLS (HTTPS only)
    │
    ├─ CrowdSec WAF (bot/attack filtering)
    │
    ├─ IP Allowlist (admin services)
    │
    ├─ Authentik SSO (identity)
    │
    └─ Docker network isolation
```

**Public services:** Overseerr, Jellyfin, Wizarr
**Protected services:** Radarr, Sonarr, Portainer (ipAllowList)
**Internal only:** Authentik admin, databases
