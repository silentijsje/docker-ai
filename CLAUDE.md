# Claude Code Instructions

## Security Requirements

**IMPORTANT: Always ensure `ai-ansible/vars/vault.yml` is encrypted before committing or pushing to GitHub.**

To check if vault is encrypted:
```bash
head -1 ai-ansible/vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

To encrypt if not encrypted:
```bash
ansible-vault encrypt ai-ansible/vars/vault.yml
```

Never commit plaintext secrets to this repository.
