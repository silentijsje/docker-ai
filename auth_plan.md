# Plan: Activate Authentik Auth (OIDC + Forward-Auth)

## Context
All services are currently IP-allowlist only — no user-level authentication. Authentik is deployed and the `authentik-auth@file` forward-auth middleware is already defined in `dynamic.yaml.j2` but applied to zero services. Goal: enable native OIDC where the app supports it, Traefik forward-auth everywhere else.

---

## Strategy

| Approach | Services | Change needed |
|---|---|---|
| **Native OIDC** | Grafana, Paperless, Vaultwarden | Env vars in compose template + Authentik app/provider |
| **Traefik forward-auth** | Everything else | Append `,authentik-auth@file` to middleware label |

---

## Phase 1 — Native OIDC

### 1a. Grafana
File: `ansible/roles/containers/templates/monitoring/docker-compose.yml.j2`

Add to grafana service environment:
```yaml
- GF_AUTH_GENERIC_OAUTH_ENABLED=true
- GF_AUTH_GENERIC_OAUTH_NAME=Authentik
- GF_AUTH_GENERIC_OAUTH_CLIENT_ID={{ vault_grafana_oidc_client_id }}
- GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET={{ vault_grafana_oidc_client_secret }}
- GF_AUTH_GENERIC_OAUTH_SCOPES=openid email profile
- GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.{{ cloudflare_dns_zone }}/application/o/authorize/
- GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.{{ cloudflare_dns_zone }}/application/o/token/
- GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.{{ cloudflare_dns_zone }}/application/o/userinfo/
- GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups[*], 'grafana-admins') && 'Admin' || 'Viewer'
- GF_AUTH_SIGNOUT_REDIRECT_URL=https://auth.{{ cloudflare_dns_zone }}/application/o/grafana/end-session/
- GF_AUTH_OAUTH_AUTO_LOGIN=true
```

### 1b. Paperless
File: `ansible/roles/containers/templates/paperless/docker-compose.yml.j2`

Add to paperless-ngx service environment:
```yaml
- PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect": {"APPS": [{"provider_id": "authentik", "name": "Authentik", "client_id": "{{ vault_paperless_oidc_client_id }}", "secret": "{{ vault_paperless_oidc_client_secret }}", "settings": {"server_url": "https://auth.{{ cloudflare_dns_zone }}/application/o/paperless/.well-known/openid-configuration"}}]}}
- PAPERLESS_DISABLE_REGULAR_LOGIN=false
```
Note: Keep `DISABLE_REGULAR_LOGIN=false` initially so admin access isn't lost if OIDC misconfigures.

### 1c. Vaultwarden
File: `ansible/roles/containers/templates/vaultwarden/docker-compose.yml.j2`

Add to environment:
```yaml
- SSO_ENABLED=true
- SSO_CLIENT_ID={{ vault_vaultwarden_oidc_client_id }}
- SSO_CLIENT_SECRET={{ vault_vaultwarden_oidc_client_secret }}
- SSO_AUTHORITY=https://auth.{{ cloudflare_dns_zone }}/application/o/vaultwarden/
- SSO_PKCE=true
```
**Risk:** SSO requires image `vaultwarden/server:testing` or ≥1.32.0. Check current image tag before enabling.

---

## Phase 2 — Traefik Forward-Auth

Append `,authentik-auth@file` to each service's middleware label.

| File | Current middleware line |
|---|---|
| `portainer/docker-compose.yml.j2:28` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `seerr/docker-compose.yml.j2:42` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `radarr/docker-compose.yml.j2:43` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `sonarr/docker-compose.yml.j2:43` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `prowlarr/docker-compose.yml.j2:42` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `sabnzbd/docker-compose.yml.j2:45` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `qbittorrent/docker-compose.yml.j2:47` | `security-headers@file,traefik-bouncer@file` (also add `ipAllowList@file`) |
| `tautulli/docker-compose.yml.j2:42` | `security-headers@file,traefik-bouncer@file,ipAllowList@file` |
| `drawio` | Replace `{{ traefik_router_middlewares }}` with hardcoded string + `authentik-auth@file` |
| `graylog` | Replace `{{ traefik_router_middlewares }}` with hardcoded string + `authentik-auth@file` |

Excluded from forward-auth:
- `homepage` — left open (IP-restricted only)
- `notifiarr` — left open (external webhooks may break)
- `lldap` — left open (chicken-and-egg risk with Authentik backend)

---

## Phase 3 — Vault Secrets

Decrypt vault, add:
```yaml
vault_grafana_oidc_client_id: <from Authentik UI>
vault_grafana_oidc_client_secret: <from Authentik UI>
vault_paperless_oidc_client_id: <from Authentik UI>
vault_paperless_oidc_client_secret: <from Authentik UI>
vault_vaultwarden_oidc_client_id: <from Authentik UI>
vault_vaultwarden_oidc_client_secret: <from Authentik UI>
```
Re-encrypt when done.

---

## Phase 4 — Authentik UI (manual, before deploy)

For each native OIDC service, create in Authentik:
1. **Provider** → OAuth2/OpenID Connect → set redirect URIs
2. **Application** → link to provider → note client ID/secret → put in vault

Redirect URIs:
- Grafana: `https://grafana.<domain>/login/generic_oauth`
- Paperless: `https://paperless.<domain>/accounts/oidc/authentik/login/callback/`
- Vaultwarden: `https://vaultwarden.<domain>/identity/connect/oidc-signin`

Also needed: Authentik **Embedded Outpost** must be configured and accessible at `http://cloud.lan:9000` for forward-auth to work.

---

## Verification

1. Deploy with `ansible-playbook` for affected host group
2. Grafana: visit URL → redirected to Authentik → login → lands in Grafana as correct role
3. Paperless: visit URL → "Login with Authentik" button visible
4. Vaultwarden: visit URL → SSO login option present
5. Forward-auth services (e.g. portainer): visit URL → redirected to Authentik → after login → service loads
6. Check `X-authentik-*` headers passed through (browser devtools)

---

## Unresolved Questions

1. Is Vaultwarden image tag ≥1.32.0 (SSO-capable)?
