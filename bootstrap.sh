#!/usr/bin/env bash
# Non-interactive first-login bootstrap for an Ubuntu 26.04 desktop.
# Run as root and it selects the first human user. Run as that user only when
# sudo works without a prompt, or when --become-password-file is set.
# This script never prompts.
set -euo pipefail

# In-code overrides. Empty values are filled from the machine. CLI flags win.
default_target_user=""
default_repo_dir=""
default_git_name=""
default_git_email=""
default_opencode_provider_base_url=""
default_session_wait="300"
default_become_password_file=""

repo_url="https://github.com/jonhowe/move-in-using-ansible.git"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
export GIT_TERMINAL_PROMPT=0

die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [options]

Non-interactive. Run as root on first login, or as the target user with
passwordless sudo or --become-password-file.

Options:
  --user NAME                         Desktop user. Default: first human account.
  --repo-dir PATH                     Checkout path. Default: ~/git/move-in-using-ansible
                                      of the target user, or this script's checkout.
  --git-name NAME                     Git user.name written to .env.yml when that file
                                      is absent. Default: the account's full name.
  --git-email ADDRESS                 Git user.email. Default: NAME@hostname.
  --opencode-provider-base-url URL    OpenCode provider URL. Default: playbook value.
  --become-password-file PATH         Sudo password file. Not required when root.
  --session-wait SECONDS              How long to wait for a GUI session. Default: 300.
  -h, --help                          Show this help.
EOF
}

yaml_quote() {
  local value="$1"
  [[ "${value}" != *$'\n'* ]] || die "override values cannot contain newlines"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "${value}"
}

parse_args() {
  target_user="${default_target_user}"
  repo_dir="${default_repo_dir}"
  git_name="${default_git_name}"
  git_email="${default_git_email}"
  opencode_provider_base_url="${default_opencode_provider_base_url}"
  session_wait="${default_session_wait}"
  become_password_file="${default_become_password_file}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)
        [[ $# -ge 2 ]] || die "--user requires a value"
        target_user="$2"
        shift 2
        ;;
      --user=*)
        target_user="${1#*=}"
        shift
        ;;
      --repo-dir)
        [[ $# -ge 2 ]] || die "--repo-dir requires a value"
        repo_dir="$2"
        shift 2
        ;;
      --repo-dir=*)
        repo_dir="${1#*=}"
        shift
        ;;
      --git-name)
        [[ $# -ge 2 ]] || die "--git-name requires a value"
        git_name="$2"
        shift 2
        ;;
      --git-name=*)
        git_name="${1#*=}"
        shift
        ;;
      --git-email)
        [[ $# -ge 2 ]] || die "--git-email requires a value"
        git_email="$2"
        shift 2
        ;;
      --git-email=*)
        git_email="${1#*=}"
        shift
        ;;
      --opencode-provider-base-url)
        [[ $# -ge 2 ]] || die "--opencode-provider-base-url requires a value"
        opencode_provider_base_url="$2"
        shift 2
        ;;
      --opencode-provider-base-url=*)
        opencode_provider_base_url="${1#*=}"
        shift
        ;;
      --become-password-file)
        [[ $# -ge 2 ]] || die "--become-password-file requires a value"
        become_password_file="$2"
        shift 2
        ;;
      --become-password-file=*)
        become_password_file="${1#*=}"
        shift
        ;;
      --session-wait)
        [[ $# -ge 2 ]] || die "--session-wait requires a value"
        session_wait="$2"
        shift 2
        ;;
      --session-wait=*)
        session_wait="${1#*=}"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done

  [[ "${session_wait}" =~ ^[0-9]+$ ]] || die "--session-wait must be a whole number of seconds"
}

load_become_password() {
  become_password=""
  if [[ -n "${become_password_file}" ]]; then
    [[ -f "${become_password_file}" ]] || die "become password file not found: ${become_password_file}"
    IFS= read -r become_password < "${become_password_file}" || true
    [[ -n "${become_password}" ]] || die "become password file is empty: ${become_password_file}"
  elif [[ -n "${ANSIBLE_BECOME_PASS:-}" ]]; then
    become_password="${ANSIBLE_BECOME_PASS}"
  fi
}

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi
  if sudo -n true 2>/dev/null; then
    sudo -n "$@"
    return
  fi
  if [[ -n "${become_password}" ]]; then
    printf '%s\n' "${become_password}" | sudo -S -p '' "$@"
    return
  fi
  die "root privileges are required. Run as root, or pass --become-password-file."
}

as_user() {
  if [[ "$(id -un)" == "${target_user}" ]]; then
    "$@"
  else
    runuser -u "${target_user}" -- "$@"
  fi
}

first_human_user() {
  getent passwd | awk -F: '
    $3 >= 1000 && $3 < 65534 && $6 ~ "^/home/" && $7 !~ /(nologin|false)$/ {
      print $3, $1
    }
  ' | sort -n | awk 'NR == 1 { print $2 }'
}

resolve_user() {
  if [[ -z "${target_user}" ]]; then
    target_user="$(first_human_user)"
    [[ -n "${target_user}" ]] || die "no human user found under /home. Pass --user."
  fi
  getent passwd "${target_user}" >/dev/null || die "user not found: ${target_user}"
  if [[ "$(id -u)" -ne 0 && "$(id -un)" != "${target_user}" ]]; then
    die "run as root or as ${target_user}"
  fi
  target_home="$(getent passwd "${target_user}" | awk -F: '{ print $6 }')"
  [[ -n "${target_home}" && -d "${target_home}" ]] || die "home directory missing for ${target_user}"
  printf 'Target user: %s (%s)\n' "${target_user}" "${target_home}"
}

require_ubuntu() {
  local version_id
  version_id="$(. /etc/os-release && printf '%s' "${VERSION_ID:-}")"
  [[ "${version_id}" == "26.04" ]] || die "Ubuntu 26.04 is required (found ${version_id:-unknown})"
}

install_tools() {
  run_root apt-get update
  run_root apt-get install -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    git ansible python3-docker
}

capture_pid_session() {
  local pid="$1"
  local line display="" wayland="" runtime="" dbus="" desktop=""
  [[ -r "/proc/${pid}/environ" ]] || return 1
  while IFS= read -r line; do
    case "${line}" in
      DISPLAY=*) display="${line#DISPLAY=}" ;;
      WAYLAND_DISPLAY=*) wayland="${line#WAYLAND_DISPLAY=}" ;;
      XDG_RUNTIME_DIR=*) runtime="${line#XDG_RUNTIME_DIR=}" ;;
      DBUS_SESSION_BUS_ADDRESS=*) dbus="${line#DBUS_SESSION_BUS_ADDRESS=}" ;;
      XDG_CURRENT_DESKTOP=*) desktop="${line#XDG_CURRENT_DESKTOP=}" ;;
    esac
  done < <(tr '\0' '\n' < "/proc/${pid}/environ")
  [[ -n "${runtime}" && ( -n "${display}" || -n "${wayland}" ) ]] || return 1
  session_display="${display}"
  session_wayland="${wayland}"
  session_runtime="${runtime}"
  session_dbus="${dbus}"
  session_desktop="${desktop}"
  return 0
}

capture_session_env() {
  local pid comm
  session_display=""
  session_wayland=""
  session_runtime=""
  session_dbus=""
  session_desktop=""

  if [[ "$(id -un)" == "${target_user}" && -n "${XDG_RUNTIME_DIR:-}" && -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    session_display="${DISPLAY:-}"
    session_wayland="${WAYLAND_DISPLAY:-}"
    session_runtime="${XDG_RUNTIME_DIR}"
    session_dbus="${DBUS_SESSION_BUS_ADDRESS:-}"
    session_desktop="${XDG_CURRENT_DESKTOP:-}"
    return 0
  fi

  while read -r pid comm; do
    case "${comm}" in
      gnome-session* | gnome-shell* | Xorg | Xwayland)
        capture_pid_session "${pid}" && return 0
        ;;
    esac
  done < <(ps -u "${target_user}" -o pid=,comm=)

  while read -r pid comm; do
    capture_pid_session "${pid}" && return 0
  done < <(ps -u "${target_user}" -o pid=,comm=)

  return 1
}

wait_for_session() {
  local deadline=$((SECONDS + session_wait))
  while true; do
    if capture_session_env; then
      printf 'GUI session: DISPLAY=%s WAYLAND_DISPLAY=%s XDG_RUNTIME_DIR=%s\n' \
        "${session_display:-<unset>}" "${session_wayland:-<unset>}" "${session_runtime}"
      return 0
    fi
    if [[ "${SECONDS}" -ge "${deadline}" ]]; then
      die "no GUI session for ${target_user} after ${session_wait}s"
    fi
    sleep 2
  done
}

resolve_git_identity() {
  local gecos host
  if [[ -z "${git_name}" ]]; then
    gecos="$(getent passwd "${target_user}" | awk -F: '{ print $5 }' | cut -d, -f1 | sed 's/[[:space:]]*$//')"
    if [[ -n "${gecos}" ]]; then
      git_name="${gecos}"
    else
      git_name="${target_user}"
    fi
  fi
  if [[ -z "${git_email}" ]]; then
    host="$(hostname -s 2>/dev/null || hostname)"
    git_email="${target_user}@${host}"
  fi
}

write_env_overrides() {
  local content
  if [[ -f "${repo_dir}/.env.yml" ]]; then
    printf 'Keeping existing .env.yml\n'
    return
  fi
  resolve_git_identity
  content="$(printf '%s\n' "---")"
  content+=$'\n'"git_user_name: $(yaml_quote "${git_name}")"
  content+=$'\n'"git_user_email: $(yaml_quote "${git_email}")"
  if [[ -n "${opencode_provider_base_url}" ]]; then
    content+=$'\n'"opencode_provider_base_url: $(yaml_quote "${opencode_provider_base_url}")"
  fi
  content+=$'\n'
  printf '%s' "${content}" | as_user bash -c 'umask 077; cat > .env.yml'
  printf 'Wrote %s/.env.yml\n' "${repo_dir}"
}

ensure_checkout() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${script_dir}/playbook.yml" && -f "${script_dir}/ansible.cfg" ]]; then
    repo_dir="${script_dir}"
    cd "${repo_dir}"
    return 0
  fi

  if [[ -z "${repo_dir}" ]]; then
    repo_dir="${target_home}/git/move-in-using-ansible"
  fi
  install_tools
  if [[ -d "${repo_dir}/.git" ]]; then
    printf 'Using existing checkout %s\n' "${repo_dir}"
  elif [[ -e "${repo_dir}" ]]; then
    die "refusing to clone over existing path ${repo_dir}"
  else
    as_user mkdir -p "$(dirname "${repo_dir}")"
    as_user git clone "${repo_url}" "${repo_dir}"
  fi
  exec "${repo_dir}/bootstrap.sh" "${original_args[@]}"
}

grant_passwordless_sudo() {
  local dropin="/etc/sudoers.d/move-in-bootstrap"
  local tmp
  sudoers_dropin=""
  if [[ "$(id -u)" -ne 0 ]]; then
    return 0
  fi
  if [[ -n "${become_password}" ]]; then
    return 0
  fi
  if [[ -e "${dropin}" ]]; then
    return 0
  fi
  tmp="$(mktemp)"
  printf '%s\n' "# Removed when bootstrap.sh exits." "${target_user} ALL=(ALL) NOPASSWD: ALL" > "${tmp}"
  chmod 0440 "${tmp}"
  visudo -cf "${tmp}" >/dev/null
  mv "${tmp}" "${dropin}"
  sudoers_dropin="${dropin}"
}

cleanup() {
  if [[ -n "${sudoers_dropin:-}" && -f "${sudoers_dropin}" ]]; then
    rm -f "${sudoers_dropin}"
  fi
}

playbook_env() {
  local -n _out=$1
  _out=(
    "HOME=${target_home}"
    "USER=${target_user}"
    "LOGNAME=${target_user}"
    "XDG_RUNTIME_DIR=${session_runtime}"
  )
  [[ -n "${session_display}" ]] && _out+=("DISPLAY=${session_display}")
  [[ -n "${session_wayland}" ]] && _out+=("WAYLAND_DISPLAY=${session_wayland}")
  [[ -n "${session_dbus}" ]] && _out+=("DBUS_SESSION_BUS_ADDRESS=${session_dbus}")
  [[ -n "${session_desktop}" ]] && _out+=("XDG_CURRENT_DESKTOP=${session_desktop}")
  if [[ -n "${become_password}" ]]; then
    _out+=("ANSIBLE_BECOME_PASS=${become_password}")
  fi
}

run_playbook() {
  local -a env_args=()
  playbook_env env_args
  (cd "${repo_dir}" && as_user env "${env_args[@]}" ansible-galaxy collection install -r collections/requirements.yml)
  (cd "${repo_dir}" && as_user env "${env_args[@]}" ansible-playbook playbook.yml)
}

main() {
  original_args=("$@")
  sudoers_dropin=""
  parse_args "$@"
  load_become_password
  require_ubuntu
  resolve_user
  ensure_checkout

  exec 9>/tmp/move-in-bootstrap.lock
  flock -n 9 || die "another bootstrap is already running"

  install_tools
  wait_for_session
  write_env_overrides
  grant_passwordless_sudo
  trap cleanup EXIT
  run_playbook
  printf 'Playbook finished. Log out and back in before using docker without sudo.\n'
}

main "$@"
