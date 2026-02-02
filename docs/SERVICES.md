# Services Reference

All services deployed in the stack with access details.

## Infrastructure Services

### Traefik
**Purpose:** Reverse proxy + TLS termination
**URL:** https://traefik.silentijsje.com
**Port:** 443 (HTTPS), 80 (HTTP redirect)
**Config:** `/docker/traefik/`
**Logs:** `/docker/logs/traefik/`
**Dependencies:** Cloudflare DNS API
**Notes:** Auto TLS via Let's Encrypt + Cloudflare DNS-01

### CrowdSec
**Purpose:** Web Application Firewall (WAF)
**URL:** N/A (headless)
**Ports:** 8080 (API), 7422 (AppSec)
**Config:** `/docker/crowdsec/`
**Dependencies:** Traefik logs
**Notes:** Blocks bots, brute force, malicious IPs

### Portainer
**Purpose:** Docker container management UI
**URL:** https://portainer.silentijsje.com
**Port:** 9000
**Dependencies:** Docker socket
**Access:** IP allowlist protected

### Homepage
**Purpose:** Service dashboard/portal
**URL:** https://home.silentijsje.com
**Dependencies:** None
**Notes:** Customizable service links

## Media Management

### Radarr
**Purpose:** Movie collection manager
**URL:** https://radarr.silentijsje.com
**Port:** 7878
**Dependencies:** Prowlarr, download clients
**Mounts:** `/mnt/media/movies`
**Access:** IP allowlist protected

### Sonarr
**Purpose:** TV series collection manager
**URL:** https://sonarr.silentijsje.com
**Port:** 8989
**Dependencies:** Prowlarr, download clients
**Mounts:** `/mnt/media/tv`
**Access:** IP allowlist protected

### Whisparr
**Purpose:** XXX content manager
**URL:** https://whisparr.silentijsje.com
**Dependencies:** Prowlarr, download clients
**Access:** IP allowlist protected

### Prowlarr
**Purpose:** Indexer aggregator for *arr apps
**URL:** https://prowlarr.silentijsje.com
**Dependencies:** None
**Notes:** Central indexer management

### Tautulli
**Purpose:** Plex server monitoring/statistics
**URL:** https://tautulli.silentijsje.com
**Port:** 8181
**Dependencies:** Plex server
**Access:** IP allowlist protected

## Request Management

### Overseerr
**Purpose:** Media request interface for users
**URL:** https://overseerr.silentijsje.com
**Port:** 5055
**Dependencies:** Radarr, Sonarr
**Access:** Public (authenticated)
**Notes:** Users request movies/shows

### Huntarr
**Purpose:** Hunt for requested media
**URL:** https://huntarr.silentijsje.com
**Dependencies:** *arr apps

### Wizarr
**Purpose:** User onboarding wizard
**URL:** https://wizarr.silentijsje.com
**Port:** 5690
**Access:** Public
**Notes:** Self-service invites

## Identity & Authentication

### Authentik
**Purpose:** Identity provider (SSO/LDAP)
**URL:** https://auth.silentijsje.com
**Dependencies:** PostgreSQL, Redis
**Database:** PostgreSQL (dedicated container)
**Cache:** Redis (dedicated container)
**Notes:** OIDC/SAML provider

### LDAP
**Purpose:** LDAP directory service
**URL:** https://ldap.silentijsje.com
**Port:** 17170
**Access:** IP allowlist protected

## Storage & Files

### Nextcloud
**Purpose:** File sync/share (Dropbox alternative)
**URL:** https://nextcloud.silentijsje.com
**Dependencies:** PostgreSQL, Redis
**Mounts:** `/mnt/media/nextcloud`
**Notes:** Calendar, contacts, files

### Immich
**Purpose:** Photo management (Google Photos alternative)
**URL:** https://immich.silentijsje.com
**Port:** 2283
**Host:** 10.0.0.81 (separate server)
**Dependencies:** PostgreSQL, Redis, ML
**Mounts:** Photo library

### Paperless
**Purpose:** Document management/archival
**URL:** https://paperless.silentijsje.com
**Port:** 3000
**Dependencies:** PostgreSQL, Redis, Tika, Gotenberg
**Notes:** OCR + searchable docs

### Mealie
**Purpose:** Recipe manager
**URL:** https://mealie.silentijsje.com
**Port:** 9925
**Dependencies:** None

### Booklore
**Purpose:** Book library management
**URL:** https://booklore.silentijsje.com
**Port:** 6060
**Database:** MariaDB (dedicated container)
**Access:** IP allowlist protected

## Support Services

### Notifiarr
**Purpose:** Notification orchestrator
**URL:** N/A (background service)
**Dependencies:** *arr apps
**Notes:** Aggregates notifications

### DDNS Updater
**Purpose:** Dynamic DNS updates
**URL:** N/A (background service)
**Dependencies:** Cloudflare API
**Notes:** Updates DNS with public IP

### Jellystat
**Purpose:** Jellyfin statistics
**URL:** https://jellystat.silentijsje.com
**Dependencies:** Jellyfin

### TracearR
**Purpose:** *arr app tracker
**URL:** https://tracearr.silentijsje.com
**Dependencies:** *arr apps

### Nebula Sync
**Purpose:** Network mesh sync
**URL:** N/A (background service)

### NewT
**Purpose:** (Purpose TBD)
**URL:** https://newt.silentijsje.com

## External Infrastructure

### Jellyfin (Primary)
**Host:** 10.0.20.10:8096
**Purpose:** Media streaming server
**URL:** https://jellyfin.silentijsje.com
**Access:** Public (authenticated)

### Jellyfin (Secondary)
**Host:** 10.0.20.91:8096
**URL:** https://jellyfin2.silentijsje.com

### qBittorrent
**Host:** 10.0.0.89:8090
**Purpose:** Torrent download client
**URL:** https://qbt.silentijsje.com
**Access:** IP allowlist protected

### NZBGet
**Host:** 10.0.0.88:7777
**Purpose:** Usenet download client
**URL:** https://nzb.silentijsje.com
**Access:** IP allowlist protected

### TrueNAS
**Host:** 10.0.0.2
**Purpose:** NAS storage
**URL:** https://truenas.silentijsje.com
**Access:** IP allowlist protected
**Notes:** Provides SMB share //10.0.40.2/media

### Pi-hole
**Host:** 10.0.0.50
**Purpose:** Network DNS + ad blocking
**URL:** https://pihole.silentijsje.com
**Access:** IP allowlist protected

### Proxmox VE 1
**Host:** 10.0.0.70:8006
**URL:** https://pve1.silentijsje.com
**Access:** IP allowlist protected

### Proxmox VE 2
**Host:** 10.0.0.71:8006
**URL:** https://pve2.silentijsje.com
**Access:** IP allowlist protected

### Proxmox Backup Server
**Host:** 10.0.0.75:8007
**URL:** https://pbs.silentijsje.com
**Access:** IP allowlist protected

### UniFi Controller
**Host:** 10.0.0.1
**URL:** https://unifi.silentijsje.com
**Access:** IP allowlist protected
