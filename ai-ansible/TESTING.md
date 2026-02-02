# Testing Guide

CI/CD testing for docker-ai Ansible playbooks using GitHub Actions and Molecule.

## CI Pipeline

### Jobs Overview

1. **Security** (parallel)
   - `secret-scan`: Gitleaks secret detection
   - `vault-check`: Verify vault files encrypted

2. **Linting** (after security)
   - `lint`: yamllint + ansible-lint

3. **Molecule Tests** (after linting)
   - Matrix: 4 roles x multiple OS/Ansible versions
   - Tests run in parallel

### Triggers

- Push to main/develop (paths: `ai-ansible/**`, `.github/workflows/ci.yml`)
- Pull requests
- Manual workflow dispatch

## Local Testing

### Prerequisites

```bash
pip install ansible-core molecule molecule-plugins[docker] docker ansible-lint yamllint
```

### Run All Checks

```bash
# From repo root
./scripts/run-ci-locally.sh
```

### Run Individual Checks

**Vault encryption:**
```bash
find ai-ansible -name "*vault*.yml" -exec head -1 {} \;
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

**YAML linting:**
```bash
cd ai-ansible
yamllint .
```

**Ansible linting:**
```bash
cd ai-ansible
ansible-lint --strict
```

**Molecule test (single role):**
```bash
cd ai-ansible/roles/bootstrap
molecule test
```

**Molecule test (specific scenario):**
```bash
cd ai-ansible/roles/bootstrap
molecule create
molecule converge
molecule verify
molecule destroy
```

## Molecule Scenarios

### Bootstrap Role
- **Platform:** Ubuntu 22.04
- **Tests:** timezone, SSH config, user creation
- **Mocked vars:** vault_users, vault_ssh_keys, vault_user_passwords

### Docker Role
- **Platform:** Ubuntu 22.04
- **Tests:** Docker installed, service running, compose plugin, user in docker group
- **Mocked vars:** vault_docker_users

### Containers Role
- **Platform:** Ubuntu 22.04 (Docker-in-Docker)
- **Tests:** Traefik only (network, directories, compose files)
- **Mocked vars:** vault_cloudflare_api_token, vault_traefik_email, vault_crowdsec_enroll_key, vault_samba_*, vault_booklore_db_*

### Proxy Role
- **Platform:** Ubuntu 22.04
- **Tests:** Config directories, templates rendered
- **Mocked vars:** vault_cloudflare_api_token, vault_traefik_email

## Troubleshooting

### Molecule Tests Fail Locally

**Issue:** Docker permission denied
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**Issue:** Molecule command not found
```bash
pip install --upgrade molecule molecule-plugins[docker]
```

### Linting Errors

**yamllint warnings:**
- Line length warnings (max 200) are acceptable
- Missing document start in static files is acceptable

**ansible-lint errors:**
- Fix by using FQCN (e.g., `ansible.builtin.copy`)
- Run `ansible-lint --fix` for auto-fixes

### Vault Not Encrypted

**Encrypt:**
```bash
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

**Verify:**
```bash
head -1 ai-ansible/vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

## GitHub Actions Secrets

**Required secrets:**
- `ANSIBLE_VAULT_PASSWORD`: Vault password (not used by default, Molecule uses mocked vars)

**Note:** Tests run with mocked variables, vault decryption not needed for CI.

## Performance

**Typical runtime:** 8-12 minutes
- Security: 30 sec
- Linting: 2 min
- Molecule tests: 6-8 min (parallel)

**Caching:**
- Python packages cached
- Ansible collections cached

## Adding New Roles

1. Create molecule scenario:
```bash
cd ai-ansible/roles/NEW_ROLE
mkdir -p molecule/default
```

2. Create files:
   - `molecule.yml`: Platform config
   - `converge.yml`: Test playbook (mock vault vars)
   - `verify.yml`: Assertions

3. Add to workflow matrix:
```yaml
matrix:
  role: [bootstrap, docker, containers, proxy, NEW_ROLE]
```

4. Test locally before committing:
```bash
cd ai-ansible/roles/NEW_ROLE
molecule test
```
