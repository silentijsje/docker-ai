#!/bin/bash
# Run CI checks locally before pushing
# Usage: ./scripts/run-ci-locally.sh [role]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ai-ansible"

echo "=========================================="
echo "Running CI checks locally"
echo "=========================================="
echo ""

# Step 1: Vault encryption check
echo ">>> Step 1: Vault encryption check"
VAULT_FILES=$(find "$ANSIBLE_DIR" -type f -name "*vault*.yml" 2>/dev/null || true)
if [ -z "$VAULT_FILES" ]; then
  echo "✓ No vault files found"
else
  UNENCRYPTED=""
  for file in $VAULT_FILES; do
    if [ -f "$file" ]; then
      FIRST_LINE=$(head -1 "$file")
      if ! echo "$FIRST_LINE" | grep -q '^\$ANSIBLE_VAULT'; then
        UNENCRYPTED="$UNENCRYPTED\n  - $file"
      else
        echo "✓ $file is encrypted"
      fi
    fi
  done

  if [ -n "$UNENCRYPTED" ]; then
    echo ""
    echo "ERROR: Unencrypted vault file(s) detected!"
    echo -e "Files:$UNENCRYPTED"
    exit 1
  fi
fi
echo ""

# Step 2: YAML linting
echo ">>> Step 2: YAML linting"
cd "$ANSIBLE_DIR"
yamllint . || true  # Show warnings but don't fail
echo ""

# Step 3: Ansible linting
echo ">>> Step 3: Ansible linting"
cd "$ANSIBLE_DIR"
ansible-lint --strict
echo ""

# Step 4: Molecule tests
if [ -n "$1" ]; then
  ROLES=("$1")
else
  ROLES=(bootstrap docker containers proxy)
fi

echo ">>> Step 4: Molecule tests"
for role in "${ROLES[@]}"; do
  echo "Testing role: $role"
  cd "$ANSIBLE_DIR/roles/$role"
  molecule test
  echo ""
done

echo "=========================================="
echo "✓ All CI checks passed!"
echo "=========================================="
