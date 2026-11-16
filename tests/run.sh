#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root"

export ANSIBLE_ROLES_PATH="$repo_root/roles"

bash -n bootstrap.sh
if grep -n -- '--ask-become-pass' bootstrap.sh; then
  printf 'bootstrap.sh must stay non-interactive\n' >&2
  exit 1
fi
ansible-playbook --syntax-check playbook.yml
ansible-playbook tests/vars_contract.yml
ansible-playbook tests/preflight_become_regression.yml
