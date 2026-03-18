# Repository Guidelines

## Project Overview

This repository is an Ansible workstation bootstrap for `localhost` on Ubuntu Desktop. It is designed to run inside an active GUI session, not a headless shell. The playbook enforces this via `preflight` checks tagged `always`.

Two plays in `playbook.yml`:
1. **System play** (`become: true`): APT packages, repos, Snaps, Docker, Resilio Sync.
2. **User play** (`become: false`): directories, Git config, Python/Node tools, GNOME settings, Flameshot.

## Project Structure

```
playbook.yml                  # Entry point; two plays (system + user GUI)
vars/main.yml                 # Repo-wide tracked defaults; override via .env.yml
.env.yml.example              # Template for untracked machine-local overrides
collections/requirements.yml  # community.general + community.docker
.ansible-lint                 # production profile; skips name[missing], galaxy[no-changelog]
.yamllint                     # extends default; 140-char line max; truthy disabled
ansible.cfg                   # Local inventory, retry disabled, auto Python
inventory                     # [localhost] 127.0.0.1 ansible_connection=local
tests/
  run.sh                      # Runs all test playbooks
  preflight_become_regression.yml
roles/
  preflight/                  # Assert Ubuntu local GUI; build gui_session_environment
  install_applications/       # Third-party APT repos + Snap installs
  apt_packages/               # Core APT packages; Synaptics keyring inline
  install_node_tools/         # npm global packages
  setup_docker/               # Enable Docker service; optionally add user to group
  setup_resilio_sync/         # Run Resilio Sync container via community.docker
  create_directories/         # Create standard workstation dirs
  configure_git/              # Write global Git identity
  install_python_tools/       # pipx packages
  update_user_dirs/           # XDG dirs, GTK bookmarks, safe Downloads symlink
  configure_gnome/            # gsettings, dconf, Ghostty config, terminal profile
  setup_flameshot/            # Wayland launcher, autostart desktop file, keybindings
  install_displaylink_repo/   # Legacy standalone role (superseded; not in playbook.yml)
```

## Build, Lint, and Test Commands

Install required collections (once, or after changing `collections/requirements.yml`):
```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Validate syntax:
```bash
ansible-playbook --syntax-check playbook.yml
```

Lint YAML formatting:
```bash
yamllint .
```

Lint Ansible roles and playbooks:
```bash
ansible-lint
```

Run all regression tests:
```bash
./tests/run.sh
```

Run a single test playbook directly:
```bash
ANSIBLE_ROLES_PATH=$(pwd)/roles ansible-playbook tests/preflight_become_regression.yml
```

Execute the full workstation setup:
```bash
ansible-playbook playbook.yml --ask-become-pass
```

Run only specific tags (e.g., base packages and apps without Docker/customization):
```bash
ansible-playbook playbook.yml --ask-become-pass --tags "base,apps"
```

**Before opening a PR, always run:** `ansible-playbook --syntax-check playbook.yml`, `yamllint .`, `ansible-lint`, and `./tests/run.sh`.

## Coding Style & Naming Conventions

### YAML Formatting
- Two-space indentation throughout.
- Maximum line length: 140 characters (enforced by `yamllint`).
- Start every file with `---`.
- Use block style for multi-line strings; avoid `>-` unless collapsing a long `fail_msg`.
- Do not quote boolean values (`true`/`false`) — `truthy` rule is disabled.

### Task Names
- Every task must have a `name` (except bare `import_tasks` calls, which skip `name[missing]`).
- Start names with an imperative verb: `Ensure`, `Install`, `Configure`, `Add`, `Remove`, `Read`, `Set`, `Assert`, `Build`, `Download`, `Check`.
- Examples: `Ensure APT keyrings directory exists`, `Install base APT packages`, `Assert a GUI session is present`.

### Module Names
- Always use fully-qualified module names: `ansible.builtin.apt`, `ansible.builtin.file`, `community.general.snap`, `community.docker.docker_container`, etc.
- Never use short names like `apt`, `file`, or `copy`.

### Variables
- Use `snake_case` for all variable names.
- Repo-wide, tracked defaults belong in `vars/main.yml`.
- Role-specific defaults belong in `roles/<role>/defaults/main.yml`.
- Machine-local overrides go in `.env.yml` (untracked); never commit this file.
- The `preflight` role caches active session facts as `active_session_user_id`, `active_session_user_uid`, `active_session_user_gid`, `active_session_env`, and `gui_session_environment`.
- Pass `environment: "{{ gui_session_environment }}"` on any task that talks to the desktop session (gsettings, dconf, git_config).

### Role Structure
- Name roles by responsibility: `install_foo`, `configure_bar`, `setup_baz`.
- Keep new automation in a role, not in `playbook.yml` directly.
- Use `import_tasks` for unconditional sub-task files; use `include_tasks` when the inclusion itself is conditional.
- Add a `meta/main.yml` with `dependencies: []` only when needed (e.g., `setup_resilio_sync`).

### Idempotency
- All tasks must be idempotent. Prefer declarative modules over `ansible.builtin.command`/`shell`.
- When `command` is unavoidable (e.g., `gsettings`), set `changed_when` explicitly and read the current value first to compare before writing.
- Use `failed_when: false` only when a non-zero exit is genuinely acceptable, with a comment explaining why.

### Privilege Boundaries
- The `preflight` role uses `become: false` on its `setup` call even when the outer play has `become: true`. This is intentional — it resolves the true desktop user's environment rather than root's. Do not remove this.
- System-level tasks go in the first play (`become: true`); user GUI tasks go in the second play (`become: false`).

### APT Repository Security
- Always use `signed-by` keyrings stored in `/etc/apt/keyrings/` as `.asc` files.
- Download keys via `ansible.builtin.get_url` with a `checksum` when one is available.
- Use `ansible.builtin.apt_repository` to manage sources; never write raw `.list` files.

## Variable Hierarchy

```
vars/main.yml           ← tracked defaults (all machines)
  └── .env.yml          ← untracked overrides (this machine only)
        └── role defaults/main.yml  ← role-scoped defaults
```

Common `.env.yml` overrides: `user`, `group`, `home_directory`, `git_user_name`, `git_user_email`, `docker_add_user_to_group`, `downloads_migrate_existing`, `pipx_packages`, `snaps_regular`, `applications`, `optional_snap_applications`.

## Testing Guidelines

- Put new test playbooks under `tests/`.
- Name tests after the behavior they protect: `<feature>_regression.yml`.
- Set `ANSIBLE_ROLES_PATH` to the repo root's `roles/` directory when running standalone (already done by `tests/run.sh`).
- Add each new test playbook to `tests/run.sh` so `./tests/run.sh` remains the single test entrypoint.
- Tests must be local-only (no external hosts, no `become` password prompts unless unavoidable).
- Write tests for: preflight checks, privilege boundary behavior, idempotent file management, and any new conditional logic.

## Commit & Pull Request Guidelines

- Short, imperative commit subjects: `Install OpenAI Codex CLI`, `Customize GNOME favorites and terminal appearance`.
- Group related role and test changes in one commit.
- PR descriptions should: explain the behavioral change, list validation commands run, and call out any `.env.yml` keys or workstation assumptions.

## Security & Secrets

- Never commit `.env.yml`, secrets, API keys, or machine-specific credentials.
- `.env.yml` and `ansible.log` are in `.gitignore` — keep them there.
- Prefer pinned package sources; use checksums for downloaded artifacts when the vendor publishes them.
- Preserve all `preflight` assertions — they enforce that the playbook runs only on a local Ubuntu GUI session as the correct user.
