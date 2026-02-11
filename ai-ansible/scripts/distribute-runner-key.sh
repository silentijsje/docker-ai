#!/bin/bash
# Distribute GitHub runner public key to all servers
# Run from: /mnt/docker-ai/ai-ansible

set -e

PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/VWQDcHpx8S09X0iqbf/OpmX62l1RIvPPK24nCxZBq github-runner@prod-ssh"

SERVERS=(
  "pihole1.lan"
  "media.lan"
  "proxy.lan"
  "immich.lan"
  "plex.lan"
  "jellyfin.lan"
  "nzb.lan"
  "torrent.lan"
  "docker01.prod.lan"
  "docker01.ota.lan"
  "prod-ssh.lan"
  "ai.lan"
)

echo "Distributing runner public key to all servers..."
echo ""

for server in "${SERVERS[@]}"; do
  echo -n "Adding key to $server... "
  if ssh -o ConnectTimeout=5 stanley@"$server" \
    "mkdir -p ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null; then
    echo "✓"
  else
    echo "✗ (unreachable)"
  fi
done

echo ""
echo "Done! Test connection from runner with:"
echo "ssh -i ~/.ssh/github_runner_ed25519 stanley@<server>"
