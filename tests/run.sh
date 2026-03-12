#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$repo_root"

export ANSIBLE_ROLES_PATH="$repo_root/roles"

ansible-playbook tests/preflight_become_regression.yml
