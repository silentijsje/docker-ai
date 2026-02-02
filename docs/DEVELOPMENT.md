# Development Guide

Contributing to docker-ai infrastructure.

## Development Workflow

### 1. Branch Strategy

**Branch naming:**
```bash
# Feature branches
git checkout -b Stanley/feature-name

# Bug fixes
git checkout -b Stanley/fix-bug-name

# Always prefix with Stanley/ (per CLAUDE.md)
```

**Main branches:**
- `main` - Production-ready code
- `develop` - Integration branch (if used)

### 2. Local Testing

**Test Ansible syntax:**
```bash
# Lint playbooks
ansible-lint ai-ansible/playbooks/*.yml

# Check playbook syntax
ansible-playbook ai-ansible/playbooks/site.yml --syntax-check

# Dry-run (check mode)
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/site.yml \
  --vault-password-file=.vault_pass \
  --check
```

**Test with Molecule:**
```bash
# Install Molecule
pip install molecule molecule-plugins[docker]

# Test specific role
cd ai-ansible/roles/docker
molecule test

# Test all roles
for role in ai-ansible/roles/*/; do
  cd "$role" && molecule test && cd -
done
```

### 3. Adding New Services

**Steps:**
1. Create compose file in `input/docker/<service>/`
2. Add to containers role
3. Update documentation
4. Test deployment

**Example: Adding new service**
```bash
# 1. Create directory structure
mkdir -p input/docker/myservice

# 2. Create docker-compose file
cat > input/docker/myservice/docker-compose.myservice.yml <<EOF
services:
  myservice:
    image: myservice/myservice:latest
    container_name: myservice
    restart: unless-stopped
    networks:
      - mediastack
    environment:
      - TZ=\${TIMEZONE:?err}
    ports:
      - \${MYSERVICE_PORT:?err}:8080
    volumes:
      - \${FOLDER_FOR_DATA:?err}/myservice:/config
    labels:
      - traefik.enable=true
      - traefik.http.routers.myservice.rule=Host(\`myservice.\${CLOUDFLARE_DNS_ZONE:?err}\`)
      - traefik.http.routers.myservice.entrypoints=secureweb
      - traefik.http.services.myservice.loadbalancer.server.port=8080
EOF

# 3. Add to containers role tasks
vim ai-ansible/roles/containers/tasks/main.yml
# Add include task for myservice

# 4. Update docs/SERVICES.md
vim docs/SERVICES.md

# 5. Test
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/containers.yml \
  --vault-password-file=.vault_pass \
  --tags=myservice
```

### 4. Adding Ansible Role

**Create new role:**
```bash
# Generate role structure
ansible-galaxy init ai-ansible/roles/myrole

# Add Molecule scenario
cd ai-ansible/roles/myrole
molecule init scenario default
```

**Role structure:**
```
ai-ansible/roles/myrole/
├── tasks/
│   └── main.yml          # Main tasks
├── templates/
│   └── config.j2         # Jinja2 templates
├── files/
│   └── static.conf       # Static files
├── vars/
│   └── main.yml          # Variables
├── molecule/
│   └── default/
│       ├── molecule.yml  # Molecule config
│       ├── converge.yml  # Test playbook
│       └── verify.yml    # Verification tests
└── README.md
```

### 5. Working with Vault

**Add new secrets:**
```bash
# Decrypt
ansible-vault decrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Edit
vim ai-ansible/vars/vault.yml

# Add variable with vault_ prefix
vault_new_secret: "secret_value"

# Encrypt
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# NEVER commit unencrypted vault!
```

**Using vault variables:**
```yaml
# In playbooks/roles
- name: Use secret
  debug:
    msg: "{{ vault_new_secret }}"
```

## Testing

### Pre-commit Checks

**Install hook:**
```bash
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Hook checks:**
- Vault encryption status
- No plaintext secrets
- YAML syntax

### CI/CD Pipeline

**Triggered on:**
- Push to `main`/`develop`
- Pull requests
- Manual dispatch

**Pipeline phases:**
1. Vault encryption verification
2. YAML/Ansible linting
3. Secret scanning (Gitleaks)
4. Molecule tests (all roles)
5. Documentation checks

**Run locally:**
```bash
# YAML lint
yamllint ai-ansible/

# Ansible lint
ansible-lint ai-ansible/playbooks/*.yml

# Secret scan
gitleaks detect --source . --verbose
```

## Code Style

### Ansible

**Naming:**
- Tasks: Descriptive, start with verb
- Variables: Snake_case, prefix with role name
- Vault vars: Prefix with `vault_`

**Example:**
```yaml
---
- name: Install Docker packages
  ansible.builtin.apt:
    name: "{{ docker_packages }}"
    state: present

- name: Template Docker daemon config
  ansible.builtin.template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
    mode: '0644'
```

### Docker Compose

**Standards:**
- Use long-form syntax
- Always specify restart policy
- Use required env vars: `${VAR:?err}`
- Add Traefik labels for services
- Use meaningful container names

**Example:**
```yaml
services:
  myapp:
    image: myapp:latest
    container_name: myapp
    restart: unless-stopped
    env_file:
      - ../.env
    networks:
      - mediastack
    environment:
      - TZ=${TIMEZONE:?err}
    volumes:
      - ${FOLDER_FOR_DATA:?err}/myapp:/data
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`myapp.${CLOUDFLARE_DNS_ZONE:?err}`)
      - traefik.http.routers.myapp.entrypoints=secureweb
```

## Pull Request Process

### 1. Create PR
```bash
# Push branch
git push origin Stanley/feature-name

# Create PR via GitHub CLI
gh pr create --title "feat: add new service" --body "Description"
```

### 2. PR Requirements
- All CI checks pass
- Documentation updated
- Vault remains encrypted
- No merge conflicts

### 3. PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation
- [ ] Refactor

## Testing
- [ ] Tested locally
- [ ] Molecule tests pass
- [ ] CI pipeline passes

## Checklist
- [ ] Documentation updated
- [ ] Vault encrypted
- [ ] CHANGELOG updated (if applicable)
```

## Release Process

**Version tagging:**
```bash
# Create tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Push tag
git push origin v1.0.0
```

**Semantic versioning:**
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## Useful Commands

```bash
# Show all vault variables
ansible-vault view ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Encrypt single string
ansible-vault encrypt_string 'secret_value' --name 'vault_var_name'

# Decrypt and edit in one command
ansible-vault edit ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Test role on specific host
ansible-playbook -i ai-ansible/inventory.ini \
  ai-ansible/playbooks/site.yml \
  --vault-password-file=.vault_pass \
  --tags=docker \
  --limit=docker01.ota.lan

# Generate encrypted password
mkpasswd --method=sha-512 | ansible-vault encrypt_string --stdin-name 'vault_password'
```

## Debugging

**Ansible debug mode:**
```bash
# Very verbose
ansible-playbook ... -vvvv

# Show task results
ansible-playbook ... -v

# Step-through mode
ansible-playbook ... --step

# Start at specific task
ansible-playbook ... --start-at-task="Task name"
```

**Molecule debug:**
```bash
# Keep instance after failure
molecule test --destroy=never

# Login to test instance
molecule login

# Manual converge
molecule converge
```
