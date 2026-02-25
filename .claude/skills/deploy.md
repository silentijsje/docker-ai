---
name: deploy
description: Run Ansible playbooks to deploy and manage infrastructure
---

# Deploy Skill

Run Ansible playbooks from the ai-ansible directory.

## Available Playbooks

- `containers.yml` - Deploy Docker containers
- `setup.yml` - Initial server setup
- `site.yml` - Full site deployment
- `update.yml` - Update existing deployments
- `proxy.yml` - Proxy configuration

## Instructions

1. Change to the ai-ansible directory first
2. Always use `--vault-password-file=.vault_pass` for vault decryption
3. Use inventory file: `-i hosts.ini`

## Default Behavior

- If user doesn't specify a playbook, ask which one to run
- Always run with `--check --diff` first (dry-run) unless user says "execute", "now", or "apply"
- Show what will change before applying

## Command Template

Dry-run:
```bash
cd /mnt/project/docker-ai/ai-ansible && ansible-playbook -i hosts.ini <playbook>.yml --vault-password-file=../.vault_pass --check --diff
```

Execute:
```bash
cd /mnt/project/docker-ai/ai-ansible && ansible-playbook -i hosts.ini <playbook>.yml --vault-password-file=../.vault_pass
```

## Limit to Specific Hosts

If user specifies a host or group, add `--limit <host_or_group>`

## Safety

- Confirm with user before running without --check
- Report any failures clearly
- Suggest checking logs if deployment fails
