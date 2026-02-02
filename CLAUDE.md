# Claude Code Instructions

- In all interactions and commit messages, be extremely concise and sacrifice grammar for the sake of concision.

## Github

- Your primary method for interacting with Github should be with the Github CLI.

## Git

- When creating branches, prefix them with Stanley/ to indicate they came from me.

## Plans

- At the end of each plan, give me a list of unresolved questions to awnser, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.

## Security Requirements

**IMPORTANT: Always ensure `ai-ansible/vars/vault.yml` is encrypted before committing or pushing to GitHub.**

To check if vault is encrypted:
```bash
head -1 ai-ansible/vars/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

To encrypt if not encrypted:
```bash
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

## Editing the Vault

When you need to add or edit secrets in the vault:

1. Decrypt the vault:
```bash
ansible-vault decrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

2. Make your changes to the file

3. **Always re-encrypt when done:**
```bash
ansible-vault encrypt ai-ansible/vars/vault.yml --vault-password-file=.vault_pass
```

Never commit plaintext secrets to this repository.

## Pre-commit Hook

A pre-commit hook is available to prevent accidentally committing unencrypted vault files.

**Install the hook:**
```bash
cp scripts/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

The hook will block commits if any vault file is not encrypted.
