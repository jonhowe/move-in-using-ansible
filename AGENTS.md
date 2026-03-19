# Repository Guidelines

## Overview
This repository bootstraps an Ubuntu workstation with Ansible.
It is meant to run on `localhost` from an active GUI session after login.
The `preflight` role enforces the local Ubuntu + GUI-session assumptions.

`playbook.yml` has two plays:
1. System configuration with `become: true`
2. Logged-in user customization with `become: false`

## Rule Sources
- Primary instructions for coding agents live in this `AGENTS.md`.
- No `.cursor/rules/` directory was found.
- No `.cursorrules` file was found.
- No `.github/copilot-instructions.md` file was found.

## Repository Layout
```text
playbook.yml
vars/main.yml
.env.yml.example
ansible.cfg
inventory
collections/requirements.yml
.ansible-lint
.yamllint
tests/
  run.sh
  preflight_become_regression.yml
roles/
  preflight/
  apt_packages/
  install_applications/
  install_node_tools/
  setup_docker/
  setup_resilio_sync/
  create_directories/
  configure_git/
  install_python_tools/
  configure_opencode/
  update_user_dirs/
  configure_gnome/
  setup_flameshot/
  install_displaylink_repo/
```

## Commands
There is no compile/build step.
Validation is collection install, syntax check, lint, and test execution.

Install collections:
```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Syntax-check the main playbook:
```bash
ansible-playbook --syntax-check playbook.yml
```

Lint YAML:
```bash
yamllint .
```

Lint Ansible:
```bash
ansible-lint
```

Run all tests:
```bash
./tests/run.sh
```

Run a single test:
```bash
ANSIBLE_ROLES_PATH="$PWD/roles" ansible-playbook tests/preflight_become_regression.yml
```

Syntax-check a single test:
```bash
ANSIBLE_ROLES_PATH="$PWD/roles" ansible-playbook --syntax-check tests/preflight_become_regression.yml
```

Run the full workstation bootstrap:
```bash
ansible-playbook playbook.yml --ask-become-pass
```

Run selected tags:
```bash
ansible-playbook playbook.yml --ask-become-pass --tags "base,apps"
```

Recommended pre-PR validation:
```bash
ansible-playbook --syntax-check playbook.yml
yamllint .
ansible-lint
./tests/run.sh
```

## Configuration Sources
- Tracked defaults live in `vars/main.yml`.
- Machine-local overrides live in `.env.yml` and must stay untracked.
- `inventory` targets `localhost` with `ansible_connection=local`.
- `ansible.cfg` disables retry files and uses `interpreter_python = auto_silent`.
- Do not commit `.env.yml`, `ansible.log`, or machine-specific values.

## YAML and Formatting
- Use two-space indentation.
- Start YAML files with `---`.
- Keep line length at or under 140 characters.
- Quote file modes like `"0644"` and `"0755"`.
- Keep booleans as YAML booleans, not quoted strings.
- Use block scalars for multi-line messages or embedded file content.

## Imports and Modules
- Always use fully qualified collection names such as `ansible.builtin.file`.
- Never use short module names like `file`, `copy`, `apt`, or `service`.
- Prefer `ansible.builtin.import_tasks` for unconditional task composition.
- Use `ansible.builtin.include_tasks` when the inclusion is conditional or looped.
- Keep substantial logic inside roles, not inline in `playbook.yml`.

## Variables and Types
- Use `snake_case` for variables, facts, defaults, and registered values.
- Keep repo-wide defaults in `vars/main.yml`.
- Keep truly role-scoped defaults in `roles/<role>/defaults/main.yml`.
- Keep structured lists consistent, for example `applications`, `gsettings`, and `optional_snap_applications`.
- Treat `desktop_session_required`, `downloads_migrate_existing`, and `docker_add_user_to_group` as real booleans.
- Prefer data structures that are easy to override from `.env.yml`.

## Naming
- Name roles by responsibility: `install_*`, `configure_*`, `setup_*`.
- Name tasks with concise imperative phrases such as `Ensure`, `Install`, `Configure`, `Add`, `Remove`, `Assert`, or `Set`.
- Bare `import_tasks` entries may remain unnamed; this matches the current lint config.
- Make names describe the user-visible outcome.

## Idempotency
- Every task must be safe to rerun.
- Prefer declarative modules over `command` and `shell`.
- When a command is unavoidable, read the current state first when practical.
- Pair `command` usage with `changed_when` when needed to preserve idempotency.
- Use guards such as `creates`, `state: present`, `state: directory`, and `append: true`.
- Follow the pattern in `roles/configure_gnome/tasks/apply_one_setting.yml`: read first, write only when different.

## Error Handling
- Fail fast with `ansible.builtin.assert` when platform, session, or variable assumptions are violated.
- Provide explicit `fail_msg` text that tells the operator what to fix.
- Use `failed_when: false` only when a non-zero exit is acceptable and intentional.
- Prefer safe migrations over destructive replacements.

## Privilege Boundaries
- Keep package, repository, service, and container work in the privileged play.
- Keep home-directory files, desktop settings, and user Git config in the unprivileged play.
- Do not remove `become: false` from the `preflight` setup task; it intentionally reads the active desktop user's facts.
- Desktop-aware tasks should pass `environment: "{{ gui_session_environment }}"`.

## Desktop Session Rules
- Assume a logged-in Ubuntu desktop session, not a headless shell.
- Reuse `gui_session_environment` instead of rebuilding GUI env vars ad hoc.
- GUI-sensitive tasks may rely on `DISPLAY`, `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, and DBus session state.
- If you change GNOME, dconf, Ghostty, or Git config behavior, verify it still works from the logged-in session.

## APT and External Sources
- Store managed keyrings under `/etc/apt/keyrings/`.
- Prefer `signed-by` repository definitions.
- Use `ansible.builtin.apt_repository` instead of writing raw `.list` files.
- Use `ansible.builtin.get_url` checksums when vendors publish them.
- Preserve the existing repository hygiene around Signal and Synaptics.

## Shell Usage
- Prefer `ansible.builtin.command` with `argv` over free-form shell commands.
- Use `ansible.builtin.shell` only when shell features are required.
- If shell is necessary, constrain it with `creates`, `chdir`, or other guards.
- Avoid new remote-script pipelines unless they match an existing deliberate pattern and no safer option is in scope.

## Testing Guidance
- Put regression playbooks under `tests/`.
- Name tests after the behavior they protect, usually `<feature>_regression.yml`.
- Add new tests to `tests/run.sh` so the suite remains centralized.
- Keep tests local and non-interactive whenever possible.
- During development, use the single-test command with `ANSIBLE_ROLES_PATH="$PWD/roles"`.

## Security
- Never commit `.env.yml`, credentials, tokens, or workstation-specific secrets.
- Be careful with Docker group membership; it is security-sensitive and effectively privileged.
- Preserve preflight safety checks unless the repository's scope is intentionally changing.

## Review Checklist
- Is the change in the right role instead of bloating `playbook.yml`?
- Did you preserve idempotency and privilege boundaries?
- Did you use FQCN module names and existing repository conventions?
- Did you update tests when behavior changed?
- Did you run syntax check, `yamllint`, `ansible-lint`, and the relevant tests?
