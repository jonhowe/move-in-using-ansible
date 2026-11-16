#!/usr/bin/env bash
# Prepare an Ubuntu 26.04 desktop session and run playbook.yml.
# A copy downloaded outside the checkout clones the repo, then runs the checkout's copy.
set -euo pipefail

repo_url="https://github.com/jonhowe/move-in-using-ansible.git"
repo_dir="${MOVE_IN_REPO_DIR:-${HOME}/git/move-in-using-ansible}"

die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

require_session() {
  local version_id
  version_id="$(. /etc/os-release && printf '%s' "${VERSION_ID:-}")"
  [[ "${version_id}" == "26.04" ]] || die "Ubuntu 26.04 is required (found ${version_id:-unknown})"
  [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || die "DISPLAY or WAYLAND_DISPLAY is required"
  [[ -n "${XDG_RUNTIME_DIR:-}" ]] || die "XDG_RUNTIME_DIR is required"
}

# Use the become password for apt when it is set, so a non-interactive run
# does not stop at a second sudo prompt. The password is not printed.
run_root() {
  if [[ -n "${ANSIBLE_BECOME_PASS:-}" ]]; then
    printf '%s\n' "${ANSIBLE_BECOME_PASS}" | sudo -S -p '' "$@"
  else
    sudo "$@"
  fi
}

yaml_quote() {
  local value="$1"
  [[ "${value}" != *$'\n'* ]] || die "override values cannot contain newlines"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "${value}"
}

install_tools() {
  run_root apt-get update
  run_root apt-get install -y git ansible python3-docker
}

write_env_overrides() {
  if [[ -f .env.yml ]]; then
    printf 'Keeping existing .env.yml\n'
    return
  fi
  if [[ -z "${GIT_USER_NAME:-}" && -z "${GIT_USER_EMAIL:-}" && -z "${OPENCODE_PROVIDER_BASE_URL:-}" ]]; then
    printf 'No .env.yml. Git identity stays at the tracked defaults.\n'
    return
  fi
  if [[ -n "${GIT_USER_NAME:-}" || -n "${GIT_USER_EMAIL:-}" ]]; then
    [[ -n "${GIT_USER_NAME:-}" && -n "${GIT_USER_EMAIL:-}" ]] || die "set both GIT_USER_NAME and GIT_USER_EMAIL"
  fi
  {
    printf '%s\n' "---"
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
      printf 'git_user_name: %s\n' "$(yaml_quote "${GIT_USER_NAME}")"
    fi
    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
      printf 'git_user_email: %s\n' "$(yaml_quote "${GIT_USER_EMAIL}")"
    fi
    if [[ -n "${OPENCODE_PROVIDER_BASE_URL:-}" ]]; then
      printf 'opencode_provider_base_url: %s\n' "$(yaml_quote "${OPENCODE_PROVIDER_BASE_URL}")"
    fi
  } > .env.yml
  printf 'Wrote .env.yml. It stays untracked.\n'
}

ensure_checkout() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${script_dir}/playbook.yml" && -f "${script_dir}/ansible.cfg" ]]; then
    cd "${script_dir}"
    return
  fi
  require_session
  install_tools
  mkdir -p "$(dirname "${repo_dir}")"
  if [[ -d "${repo_dir}/.git" ]]; then
    printf 'Using existing checkout %s\n' "${repo_dir}"
  elif [[ -e "${repo_dir}" ]]; then
    die "refusing to clone over existing path ${repo_dir}"
  else
    git clone "${repo_url}" "${repo_dir}"
  fi
  exec "${repo_dir}/bootstrap.sh"
}

ensure_checkout
require_session
install_tools
write_env_overrides
ansible-galaxy collection install -r collections/requirements.yml
if [[ -n "${ANSIBLE_BECOME_PASS:-}" ]]; then
  ansible-playbook playbook.yml
else
  ansible-playbook playbook.yml --ask-become-pass
fi
printf 'Playbook finished. Log out and back in before using docker without sudo.\n'
