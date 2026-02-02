# Security Guide

Security considerations & best practices.

## Threat Model

**Protected against:**
- Unauthorized external access
- Bot/scraper attacks
- Brute force attempts
- Common web vulnerabilities
- Accidental secret exposure

**NOT protected against:**
- Physical access to servers
- Compromised admin credentials
- Insider threats
- Zero-day exploits

## Security Layers

### Layer 1: Network

**Firewall rules:**
```bash
# Only expose necessary ports
- 80/tcp   (HTTP → 443 redirect)
- 443/tcp  (HTTPS)
- 22/tcp   (SSH - internal only)

# Block all other incoming by default
```

**Network segmentation:**
- Management VLAN (10.0.0.0/24) - Admin services
- Media VLAN (10.0.20.0/24) - Media servers
- Docker bridge (172.18.0.0/16) - Container network

**DNS security:**
- Pi-hole for DNS filtering
- Cloudflare DNS for external resolution
- DNSSEC validation

### Layer 2: Access Control

**SSH hardening:**
```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
```

**IP allowlisting:**
Restricted services use Traefik middleware:
```yaml
middlewares:
  - ipAllowList@file
```

**Services with IP restrictions:**
- Portainer
- Radarr/Sonarr/Prowlarr
- Traefik dashboard
- TrueNAS/Proxmox
- qBittorrent/NZBGet
- LDAP admin

### Layer 3: Traefik Reverse Proxy

**TLS enforcement:**
- All traffic HTTPS only
- HTTP → HTTPS redirect
- TLS 1.2+ only
- Strong cipher suites

**Security headers:**
```yaml
middlewares:
  security-headers:
    headers:
      sslRedirect: true
      forceSTSHeader: true
      stsIncludeSubdomains: true
      stsPreload: true
      stsSeconds: 31536000
      frameDeny: true
      contentTypeNosniff: true
      browserXssFilter: true
```

**TLS certificates:**
- Let's Encrypt via Cloudflare DNS-01
- Automatic renewal
- Wildcard certs: *.silentijsje.com

### Layer 4: CrowdSec WAF

**Protection features:**
- Bot detection
- Brute force prevention
- IP reputation scoring
- Geographic blocking (optional)
- CVE-based rules

**Bouncer integration:**
```yaml
middlewares:
  - traefik-bouncer@file
```

**Decision types:**
- Ban (permanent/temporary)
- Captcha challenge
- Rate limiting

**Monitor decisions:**
```bash
docker exec crowdsec cscli decisions list
docker exec crowdsec cscli metrics
```

### Layer 5: Application Auth

**Authentik SSO:**
- Central identity provider
- OIDC/SAML integration
- MFA support (TOTP)
- Password policies

**Service-specific auth:**
- Each service has own credentials
- No shared passwords
- Strong password requirements

## Secrets Management

### Ansible Vault

**Encrypted secrets:**
```bash
# Check encryption status
head -1 ai-ansible/vars/vault.yml
# Must show: $ANSIBLE_VAULT;1.1;AES256
```

**What's in vault:**
- User password hashes
- SMB credentials
- Cloudflare API token
- Database passwords
- Internal IP addresses
- API keys

**Vault best practices:**
- Keep .vault_pass secure (offline storage)
- Never commit unencrypted vault
- Pre-commit hook enforces encryption
- Rotate vault password quarterly

### Environment Variables

**Sensitive env vars:**
```bash
# input/.env (gitignored)
CLOUDFLARE_DNS_API_TOKEN=xxx
CROWDSEC_LAPI_KEY=xxx
DATABASE_PASSWORD=xxx
```

**Never:**
- Commit .env to Git
- Share .env publicly
- Include secrets in Docker labels

### Secret Rotation

**Quarterly rotation:**
- [ ] Cloudflare API token
- [ ] Vault password
- [ ] Database passwords
- [ ] CrowdSec LAPI key

**Annual rotation:**
- [ ] SSH keys
- [ ] TLS certificates (auto-renewed)
- [ ] User passwords

**After rotation:**
```bash
# Update vault
ansible-vault decrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
vim ai-ansible/vars/vault.yml
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Re-deploy
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/site.yml \
  --vault-password-file=.vault_pass
```

## Container Security

### Base images
- Use official images only
- Pin versions (avoid :latest in prod)
- Scan for vulnerabilities

### User permissions
```yaml
# Run as non-root
user: ${PUID}:${PGID}

# Read-only root filesystem where possible
read_only: true
```

### Resource limits
```yaml
# Prevent DoS
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

### Network isolation
- Containers on private bridge network
- No --network=host
- Only expose required ports

## Monitoring & Alerts

### Log aggregation
```bash
# Traefik access logs
tail -f /docker/logs/traefik/access.log

# CrowdSec alerts
docker exec crowdsec cscli alerts list
```

### Suspicious activity indicators
- Failed login attempts (SSH, services)
- CrowdSec bans
- Unusual traffic patterns
- High resource usage
- Unauthorized config changes

### Alerting
- CrowdSec → Notifiarr
- Failed backup jobs
- Disk space warnings
- Certificate expiration

## Incident Response

### If compromised

**1. Isolate:**
```bash
# Shutdown affected services
docker stop $(docker ps -q)

# Disconnect from network
ip link set eth0 down
```

**2. Investigate:**
```bash
# Check logs
docker logs <container>
grep -i "failed" /var/log/auth.log

# Check active connections
netstat -tuln
ss -tuln

# Check CrowdSec decisions
docker exec crowdsec cscli decisions list
```

**3. Remediate:**
- Rotate all secrets
- Update vulnerable software
- Restore from known-good backup
- Block malicious IPs

**4. Document:**
- What happened
- How detected
- Actions taken
- Lessons learned

### After incident
- [ ] Rotate all credentials
- [ ] Update firewall rules
- [ ] Patch vulnerabilities
- [ ] Review logs for IOCs
- [ ] Update runbooks

## Security Checklist

### Initial deployment
- [ ] Vault encrypted
- [ ] SSH key auth only
- [ ] Firewall configured
- [ ] TLS certificates valid
- [ ] CrowdSec enabled
- [ ] IP allowlists configured
- [ ] Strong passwords set
- [ ] MFA enabled (where available)

### Monthly
- [ ] Review CrowdSec decisions
- [ ] Check failed login attempts
- [ ] Verify backups working
- [ ] Update containers
- [ ] Scan for vulnerabilities

### Quarterly
- [ ] Rotate API keys
- [ ] Update dependencies
- [ ] Review user access
- [ ] Test disaster recovery
- [ ] Security audit

### Annually
- [ ] Rotate all secrets
- [ ] Review security policies
- [ ] Update threat model
- [ ] Penetration test (optional)

## Vulnerability Management

### Update strategy
```bash
# Update container images
docker compose pull
docker compose up -d

# Update Ansible roles
ansible-galaxy collection install -r requirements.yml --force

# Update OS packages
ansible -i ai-ansible/inventory.ini docker_hosts \
  -m apt -a "upgrade=dist" --become
```

### Security scanning
```bash
# Scan Docker images
docker scan <image>

# Scan Ansible playbooks
ansible-lint ai-ansible/playbooks/*.yml

# Secret scanning
gitleaks detect --source . --verbose
```

## Compliance

**Data protection:**
- Vault encryption at rest
- TLS in transit
- Regular backups
- Access logging

**Audit trail:**
- Git commits (who changed what)
- Ansible logs (what was deployed)
- Traefik access logs (who accessed what)
- CrowdSec decisions (security events)

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Traefik Security](https://doc.traefik.io/traefik/https/acme/)
- [CrowdSec Docs](https://docs.crowdsec.net/)

## Reporting Security Issues

**Private disclosure:**
- GitHub Security Advisory
- Email: security@silentijsje.com

**Do NOT:**
- Open public issues for vulnerabilities
- Share exploits publicly
- Test on production without permission
