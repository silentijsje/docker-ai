**Title:** SMB Mount Hardening in `setup.yml` (Preflight + Resilient Options)

**Summary**
We will harden the SMB mount tasks in `setup.yml` by adding a reachability preflight, resilient mount options, and controlled failure behavior. The play will fail on `docker01.prod.lan` if the SMB server is unreachable; other hosts will log a warning and skip the mount. Mounts will use safer systemd options to avoid blocking boot and will retry on transient failures.

**Public Interfaces / Variables**
We will introduce these new tunables in `vars/docker-vars.yml` (all optional defaults):
- `smb_wait_timeout`: integer seconds (default `5`)
- `smb_mount_retries`: integer (default `3`)
- `smb_mount_delay`: integer seconds (default `5`)
- `smb_mount_opts_extra`: string (default `"_netdev,nofail,x-systemd.automount,x-systemd.device-timeout=30"`)

No external API changes; only Ansible vars/tasks.

**Implementation Steps**
1. **Derive SMB server IP from `smb_share_path`**
   - In the SMB tasks section of `setup.yml`, add a `set_fact`:
     - `smb_server: "{{ smb_share_path | regex_replace('^//','') | regex_replace('/.*$','') }}"`

2. **Preflight reachability check**
   - Add a `wait_for` task before the mount:
     - Host: `{{ smb_server }}`
     - Port: `445`
     - Timeout: `{{ smb_wait_timeout | default(5) }}`
     - `register: smb_wait`
     - `changed_when: false`
     - `failed_when: false` (so we can handle outcome manually)

3. **Fail on prod if unreachable**
   - Add a `fail` task:
     - Condition: `smb_wait.failed and inventory_hostname == 'docker01.prod.lan'`
     - Message: include SMB host/port and guidance to check routing/firewall/NAS

4. **Warn + skip on non-prod**
   - Add a `debug` warning task:
     - Condition: `smb_wait.failed and inventory_hostname != 'docker01.prod.lan'`
     - Message: SMB unreachable, skipping mount on this host

5. **Resilient mount options + retries**
   - Update mount task:
     - Add `when: not smb_wait.failed`
     - Use:
       - `register: smb_mount_result`
       - `retries: "{{ smb_mount_retries | default(3) }}"`
       - `delay: "{{ smb_mount_delay | default(5) }}"`
       - `until: smb_mount_result is succeeded`
     - Update `opts` to append `smb_mount_opts_extra`:
       - `"rw,vers=3,credentials=/root/.smbcredentials,uid={{ container_puid }},gid={{ container_pgid }},file_mode=0770,dir_mode=0770,{{ smb_mount_opts_extra | default('_netdev,nofail,x-systemd.automount,x-systemd.device-timeout=30') }}"`
     - Keep `state: mounted` to ensure fstab entry + mount

**Test Cases / Validation**
1. **Happy path**
   - Run `ansible-playbook setup.yml --limit docker_vm`
   - Expect: mount succeeds on both hosts; no failures.
2. **SMB unreachable on prod**
   - Temporarily block access or point `vault_smb_share_path` to a non-routable IP for `docker01.prod.lan`
   - Expect: preflight fails and play stops with clear error.
3. **SMB unreachable on non-prod**
   - Make `docker01.ota.lan` unreachable to SMB
   - Expect: warning logged, mount skipped, play continues.

**Assumptions / Defaults**
- `docker01.prod.lan` is the only host requiring hard failure on SMB outage.
- Port `445` is the correct liveness signal for SMB.
- The `smb_share_path` is always in `//host/share` format.
- We keep implementation inline in `setup.yml` per your preference.
