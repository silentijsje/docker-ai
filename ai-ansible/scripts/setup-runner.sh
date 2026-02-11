#!/bin/bash
# Self-hosted GitHub Actions runner setup script
# Run on prod-ssh.lan

set -e

PLAYBOOK_PATH="/mnt/docker-ai/ai-ansible"

echo "Setting up GitHub Actions self-hosted runner..."

# Create runner directory
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download latest runner
RUNNER_VERSION="2.321.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Set work directory to playbook location
WORK_DIR="${PLAYBOOK_PATH}/_work"
mkdir -p "${WORK_DIR}"

echo ""
echo "Runner files extracted to ~/actions-runner"
echo "Work directory: ${WORK_DIR}"
echo ""
echo "Next steps:"
echo "1. Go to: https://github.com/silentijsje/docker-ai/settings/actions/runners/new"
echo "2. Copy the token from the page"
echo "3. Run: cd ~/actions-runner"
echo "4. Run: ./config.sh --url https://github.com/silentijsje/docker-ai --token YOUR_TOKEN --work ${WORK_DIR}"
echo "5. Run as service: sudo ./svc.sh install && sudo ./svc.sh start"
