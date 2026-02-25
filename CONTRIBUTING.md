# Contributing to docker-ai

Guidelines for contributing.

## Getting Started

1. Fork repository
2. Clone fork locally
3. Install pre-commit hook
4. Create feature branch (prefix: `Stanley/`)

## Pre-commit Hook

**Required before committing:**
```bash
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Hook prevents:**
- Committing unencrypted vault files
- Pushing plaintext secrets
- YAML syntax errors

## Branch Naming

**Format:** `Stanley/description`

**Examples:**
- `Stanley/add-jellyseerr`
- `Stanley/fix-traefik-routing`
- `Stanley/update-docs`

## Commit Messages

**Format:** `type: description`

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code refactor
- `test:` Add/update tests
- `chore:` Maintenance

**Examples:**
```
feat: add Jellyseerr service
fix: correct Traefik middleware order
docs: update SERVICES.md with new endpoints
chore: re-encrypt vault
```

**Co-authored commits:**
All commits include:
```
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

## Code Standards

### Ansible
- Use long-form module names (`ansible.builtin.copy`)
- Descriptive task names starting with verbs
- Variables prefixed by role name
- Vault variables prefixed with `vault_`

### Docker Compose
- Long-form YAML syntax
- Required env vars: `${VAR:?err}`
- Always specify `restart` policy
- Use Traefik labels for routing

### Documentation
- Concise, sacrifice grammar for brevity
- Use code blocks for commands
- Update relevant docs when adding features

## Testing Requirements

### Before PR
```bash
# 1. Syntax check
ansible-playbook ai-ansible/site.yml --syntax-check

# 2. Lint
ansible-lint ai-ansible/*.yml

# 3. Molecule test (if role changed)
cd ai-ansible/roles/<role> && molecule test

# 4. Vault encrypted
head -1 ai-ansible/vars/vault.yml
# Must show: $ANSIBLE_VAULT;1.1;AES256
```

### CI Pipeline
All PRs trigger CI:
- Phase 1: Vault encryption check
- Phase 2: YAML/Ansible linting
- Phase 3: Secret scanning (Gitleaks)
- Phase 4: Molecule tests (all roles)
- Phase 5: Documentation validation

**PRs require:**
- ✅ All CI checks pass
- ✅ No merge conflicts
- ✅ Documentation updated
- ✅ Vault encrypted

## Pull Request Process

### 1. Create PR
```bash
git push origin Stanley/feature-name
gh pr create --title "feat: description" --body "Details"
```

### 2. PR Template
```markdown
## Description
What this PR does

## Changes
- Change 1
- Change 2

## Testing
- [ ] Tested locally
- [ ] Molecule tests pass
- [ ] Documentation updated
- [ ] Vault encrypted
```

### 3. Review
- Maintainer reviews code
- Address feedback
- Merge when approved + CI passes

## Adding Services

**Checklist:**
1. Create `input/docker/<service>/docker-compose.<service>.yml`
2. Add task in `ai-ansible/roles/containers/tasks/`
3. Update `docs/SERVICES.md`
4. Test deployment
5. Update `README.md` if needed

## Working with Vault

**CRITICAL: Never commit unencrypted vault!**

```bash
# Decrypt
ansible-vault decrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Edit
vim ai-ansible/vars/vault.yml

# ALWAYS re-encrypt
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass

# Verify
head -1 ai-ansible/vars/vault.yml
```

**Pre-commit hook blocks unencrypted commits.**

## Security

**Report vulnerabilities:**
- GitHub Issues (private security advisory)
- DO NOT commit secrets
- DO NOT share `.vault_pass`

**Sensitive data:**
- Passwords → vault
- API keys → vault
- IP addresses → vault (internal)
- Certificates → vault or encrypted storage

## Documentation

**Update when:**
- Adding service → `docs/SERVICES.md`
- Changing architecture → `docs/ARCHITECTURE.md`
- Adding troubleshooting → `docs/TROUBLESHOOTING.md`
- Changing setup → `docs/SETUP.md`
- New dev process → `docs/DEVELOPMENT.md`

**Style:**
- Concise
- Code blocks for commands
- Examples included

## Questions?

- Read `docs/DEVELOPMENT.md`
- Check existing issues
- Open discussion in Issues

## License

By contributing, you agree your contributions will be licensed under the same license as the project.
