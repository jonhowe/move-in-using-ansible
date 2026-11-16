#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root"

export ANSIBLE_ROLES_PATH="$repo_root/roles"

bash -n bootstrap.sh
ansible-playbook --syntax-check playbook.yml
ansible-playbook tests/vars_contract.yml
ansible-playbook tests/preflight_become_regression.yml
