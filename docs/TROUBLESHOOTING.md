# Troubleshooting Guide

Common issues & solutions.

## Deployment Issues

### Ansible Connection Failed
```bash
# Test connectivity
ansible -i ai-ansible/hosts.ini docker_hosts -m ping

# Common causes:
# - SSH key not copied: ssh-copy-id user@host
# - Wrong user/host in inventory
# - Firewall blocking SSH (port 22)
# - Host key verification: ssh-keyscan -H host >> ~/.ssh/known_hosts
```

### Vault Decryption Failed
```bash
# Check vault password file exists
ls -la .vault_pass

# Verify vault is encrypted
head -1 ai-ansible/vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256

# Manual decrypt test
ansible-vault view ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

### Playbook Task Failed
```bash
# Re-run with verbose output
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/site.yml \
  --vault-password-file=.vault_pass \
  -vvv

# Check specific host
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/site.yml \
  --vault-password-file=.vault_pass \
  --limit=docker01.ota.lan
```

## Container Issues

### Container Won't Start
```bash
# Check logs
docker logs <container_name>
docker logs --tail=50 <container_name>

# Check container status
docker ps -a | grep <container_name>

# Inspect container config
docker inspect <container_name>

# Check resource constraints
docker stats
```

### Container Exits Immediately
```bash
# Common causes:
# - Missing environment variables
# - Permission issues (PUID/PGID)
# - Port conflicts
# - Mount path doesn't exist

# Check env file
cat input/.env

# Check mounts exist
ls -la /docker
ls -la /mnt/media

# Check port conflicts
netstat -tulpn | grep <port>
```

### Container Can't Access Network
```bash
# Check Docker networks
docker network ls
docker network inspect mediastack

# Restart networking
docker network disconnect mediastack <container>
docker network connect mediastack <container>

# Check DNS
docker exec <container> nslookup google.com
docker exec <container> ping -c 3 8.8.8.8
```

## Traefik Issues

### 502 Bad Gateway
```bash
# Check backend service is running
docker ps | grep <service>

# Check Traefik can reach service
docker exec traefik ping -c 3 <service_name>

# Check Traefik logs
docker logs traefik --tail=100
tail -f /docker/logs/traefik/access.log

# Verify routing config
docker exec traefik cat /etc/traefik/traefik.yaml
docker exec traefik cat /etc/traefik/internal.yaml
```

### TLS Certificate Issues
```bash
# Check cert status
ls -la /docker/traefik/letsencrypt/

# Check Cloudflare API token
docker exec traefik env | grep CF_DNS_API_TOKEN

# Force cert renewal (remove old cert)
rm /docker/traefik/letsencrypt/acme.json
docker restart traefik

# Check cert logs
docker logs traefik | grep -i certificate
```

### Service Not Reachable
```bash
# Check DNS resolution
nslookup service.silentijsje.com

# Check Cloudflare DNS records
# Login to Cloudflare dashboard → DNS records

# Check Traefik routing
docker exec traefik wget -O- http://localhost:8080/api/http/routers

# Check middlewares applied
docker logs traefik | grep -i middleware
```

## Mount/Storage Issues

### SMB Mount Failed
```bash
# Check mount status
mount | grep cifs
df -h | grep media

# Test SMB connection
smbclient //10.0.40.2/media -U pve-smb

# Check credentials in vault
ansible-vault view ai-ansible/vars/vault.yml --vault-password-file=.vault_pass | grep smb

# Remount manually
umount /mnt/media
mount -t cifs //10.0.40.2/media /mnt/media -o credentials=/path/to/creds

# Check fstab entry
cat /etc/fstab | grep media
```

### Permission Denied on Mounts
```bash
# Check PUID/PGID in .env
cat input/.env | grep -E 'PUID|PGID'

# Check actual UID/GID
id stanley

# Check mount permissions
ls -la /mnt/media/
ls -la /docker/

# Fix ownership
chown -R 1000:1000 /docker/<service>
```

## CrowdSec Issues

### Traefik Bouncer Not Working
```bash
# Check CrowdSec API
docker exec crowdsec cscli lapi status

# Check bouncer registration
docker exec crowdsec cscli bouncers list

# Check decisions
docker exec crowdsec cscli decisions list

# Check Traefik can reach CrowdSec
docker exec traefik ping -c 3 crowdsec
```

### Legitimate Traffic Blocked
```bash
# Check IP in decisions
docker exec crowdsec cscli decisions list | grep <ip>

# Remove decision
docker exec crowdsec cscli decisions delete --ip <ip>

# Add to allowlist
docker exec crowdsec cscli decisions add --ip <ip> --type captcha --duration 0s
```

## Database Issues

### PostgreSQL Connection Failed
```bash
# Check PostgreSQL container
docker ps | grep postgres
docker logs postgresql

# Test connection from app
docker exec <app_container> pg_isready -h postgresql -p 5432

# Connect to DB
docker exec -it postgresql psql -U <user> -d <database>
```

### Redis Connection Failed
```bash
# Check Redis container
docker ps | grep redis
docker logs redis

# Test Redis connection
docker exec redis redis-cli ping
# Should return: PONG
```

## Performance Issues

### High CPU Usage
```bash
# Check container resources
docker stats

# Check system resources
top
htop

# Check logs for errors
docker logs <high_cpu_container> --tail=100

# Restart container
docker restart <container>
```

### Slow Response Times
```bash
# Check Traefik access logs
tail -f /docker/logs/traefik/access.log

# Check backend response times
docker logs traefik | grep -i duration

# Check disk I/O
iostat -x 1

# Check network
iftop
nethogs
```

## Recovery Procedures

### Reset Single Service
```bash
# Stop container
docker stop <service>

# Remove container (keeps data)
docker rm <service>

# Re-deploy via Ansible
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/containers.yml \
  --vault-password-file=.vault_pass \
  --tags=<service>
```

### Reset All Containers
```bash
# Stop all
docker compose -f input/docker/*/docker-compose.*.yml down

# Re-deploy
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/containers.yml \
  --vault-password-file=.vault_pass
```

### Nuclear Option (Full Reset)
```bash
# DANGER: Removes all containers and volumes
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker volume prune -f
docker network prune -f

# Re-deploy from scratch
ansible-playbook -i ai-ansible/hosts.ini \
  ai-ansible/site.yml \
  --vault-password-file=.vault_pass
```

## Log Locations

```
/docker/logs/traefik/access.log    - Traefik access logs
/docker/logs/traefik/traefik.log   - Traefik error logs
/docker/crowdsec/data/             - CrowdSec logs
/docker/<service>/logs/            - Service-specific logs
/var/log/syslog                    - System logs
```

## Getting Help

Check logs in order:
1. Container logs: `docker logs <container>`
2. Traefik access logs: `/docker/logs/traefik/access.log`
3. System logs: `/var/log/syslog`
4. Ansible output: `-vvv` flag

GitHub Issues: https://github.com/silentijsje/docker-ai/issues
