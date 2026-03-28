#!/bin/bash
export var_backup=no
export var_container=all_running
export var_unattended=yes
export var_skip_confirm=yes
export var_auto_reboot=no

LOG="/var/log/lxc-update-$(date +%Y%m%d).log"
echo "=== LXC Update started at $(date) ===" >> "$LOG"

bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/update-apps.sh)" >> "$LOG" 2>&1

echo "=== LXC Update finished at $(date) ===" >> "$LOG"