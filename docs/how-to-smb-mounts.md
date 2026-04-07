# How to: Mount SMB Shares into Docker Containers

This guide explains how to mount SMB/CIFS network shares directly inside Docker containers using Docker's built-in CIFS volume driver. No host-level fstab entry is needed — the mount is declared in the container's compose file and managed by Docker.

---

## Prerequisites

- `cifs-utils` must be installed on the Docker host (already handled by `setup.yml` for SMB hosts)
- SMB credentials must be stored in `ansible/vars/vault.yml` (never in plaintext)

---

## Step 1 — Add the share path to the vault

Decrypt, add the variable, re-encrypt:

```bash
scripts/vault decrypt
```

Edit `ansible/vars/vault.yml` and add:

```yaml
vault_smb_<share>_path_<env>: "//<server-ip>/<share-name>"
```

**Naming convention:**
- `<share>` — short name for the share (e.g. `immich`, `backups`)
- `<env>` — environment suffix (`ota` or omit for prod)

Example:
```yaml
vault_smb_immich_share_path_ota: "//10.0.40.2/immich"
vault_smb_backups_share_path: "//10.0.50.2/backups"
```

```bash
scripts/vault encrypt
```

---

## Step 2 — Expose the variable in group_vars

Add a human-readable alias in the appropriate `ansible/group_vars/<group>.yml`:

```yaml
# ansible/group_vars/docker_OTA.yml
smb_immich_path: "{{ vault_smb_immich_share_path_ota }}"
```

```yaml
# ansible/group_vars/docker_vm.yml  (prod)
smb_backups_path: "{{ vault_smb_backups_share_path }}"
```

> **Scoping:** By only defining `smb_<share>_path` in a specific group_vars file, the mount will only appear in containers deployed to that environment. The Jinja2 `is defined` guard in the compose template (Step 3) handles the rest automatically.

---

## Step 3 — Add the volume to the container's compose template

In `ansible/roles/containers/templates/<service>/docker-compose.yml.j2`, add two blocks:

### 3a. Volume mount (inside the service)

```yaml
    volumes:
      - /docker/<service>:/config       # existing volumes
      - {{ container_media_root }}:/mnt/media
{% if smb_immich_path is defined %}
      - immich_smb:/mnt/immich
{% endif %}
```

### 3b. Named volume definition (bottom of the file, after `networks:`)

```yaml
{% if smb_immich_path is defined %}

volumes:
  immich_smb:
    driver: local
    driver_opts:
      type: cifs
      o: "username={{ smb_credentials.username }},password={{ smb_credentials.password }},uid={{ container_puid }},gid={{ container_pgid }},vers=3.0,_netdev"
      device: "{{ smb_immich_path }}"
{% endif %}
```

**Variables used:**
| Variable | Source |
|---|---|
| `smb_credentials.username/password` | `vars/users.yml` → vault |
| `container_puid` / `container_pgid` | `roles/containers/defaults/main.yml` |
| `smb_immich_path` | `group_vars/<env>.yml` → vault |

---

## Step 4 — Deploy

```bash
ansible-playbook ansible/containers.yml -i ansible/hosts.ini \
  --limit <host_group> \
  --vault-password-file .vault_pass
```

> Do **not** use `--tags <service>` — sub-tasks inside `include_tasks` don't inherit tags, so the compose template won't be re-rendered. Always run the full playbook scoped by `--limit`.

---

## Adding the same share to multiple containers

Repeat Step 3 for each container's compose template. The vault variable and group_vars entry are defined once and reused across all templates.

Example — mounting `immich_smb` in both sabnzbd and radarr:

```yaml
# sabnzbd/docker-compose.yml.j2
{% if smb_immich_path is defined %}
      - immich_smb:/mnt/immich
{% endif %}
```

```yaml
# radarr/docker-compose.yml.j2
{% if smb_immich_path is defined %}
      - immich_smb:/mnt/immich
{% endif %}
```

Both get the named volume block at the bottom. Docker Compose deduplicates the actual volume — only one CIFS mount is created on the host regardless of how many containers reference it.

---

## Cleanup — removing a share

**1. Remove from compose templates** — delete the `{% if %}` blocks from each service template.

**2. Remove from group_vars** — delete the `smb_<share>_path` line.

**3. Remove from vault** — decrypt, delete the `vault_smb_*` line, re-encrypt.

**4. Redeploy** — run the playbook; containers are recreated without the volume.

**5. Prune the Docker volume on the host:**

```bash
docker volume rm <project>_<share>_smb
# e.g.: docker volume rm docker_immich_smb
```

> The project name prefix (`docker_`) comes from the directory name where the master compose file lives (`/docker/docker-compose.yml`).
