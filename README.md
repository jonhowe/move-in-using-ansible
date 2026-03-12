# Ansible Playbook: Move-In Using Ansible

This repository bootstraps an Ubuntu workstation after login. It is intended to run on the local machine inside the active GUI session, not from a headless shell.

## What this playbook does

- installs baseline APT packages
- adds third-party APT repositories with `signed-by` keyrings
- installs desktop applications from APT or Snap
- enables Docker and optionally adds the logged-in user to the `docker` group
- runs Resilio Sync in Docker
- configures Git, XDG user directories, GNOME settings, and Flameshot
- installs optional Python CLI tools with `pipx`

## Safety and behavior changes

- The playbook now fails fast if it is not running on local Ubuntu or if no GUI session is present.
- Local overrides are loaded from `.env.yml` if the file exists.
- Existing files in `~/Downloads` are never deleted silently.
  - If files are present, they are moved into the synced Downloads directory first.
  - The playbook prints a message when this happens.
- The old direct-download installers for Joplin, Zoom, and Rambox were replaced with Snap installs to avoid running mutable remote scripts or installing arbitrary `latest` `.deb` files.
- Python packages are now expected to be installed with `pipx` instead of system `pip`.

## Requirements

- Ubuntu desktop session
- `sudo` access
- Ansible installed on the machine being configured
- Collections from [`collections/requirements.yml`](collections/requirements.yml)

Install collections with:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

## Configuration

Tracked defaults live in [`vars/main.yml`](vars/main.yml).

For machine-specific overrides, copy [`.env.yml.example`](.env.yml.example) to `.env.yml` and edit only the values you want to change.

`.env.yml` is YAML, not dotenv syntax. That is intentional so nested Ansible variables remain easy to override.

Common overrides:

- `user`, `group`, `home_directory`
- `git_user_name`, `git_user_email`
- `docker_add_user_to_group`
- `downloads_migrate_existing`
- `pipx_packages`
- `joplin`, `zoom`, `rambox`

## Running

Run locally:

```bash
ansible-playbook playbook.yml --ask-become-pass
```

Run a subset with tags:

```bash
ansible-playbook playbook.yml --ask-become-pass --tags "base,apps"
```

## Roles

- `preflight` validates Ubuntu, local execution, the logged-in GUI session, and key variables
- `apt_packages` installs core Ubuntu packages and the Synaptics keyring package for DisplayLink when needed
- `install_applications` manages third-party APT repositories plus shared Snap installs
- `install_joplin`, `install_zoom`, `install_rambox` install those apps from Snap
- `setup_docker` starts Docker and optionally adds the logged-in user to the `docker` group
- `setup_resilio_sync` starts the Resilio Sync container
- `create_directories` creates the standard workstation directories
- `configure_git` writes Git identity into the logged-in user's global Git config
- `install_python_tools` installs optional user CLI tools with `pipx`
- `update_user_dirs` sets XDG/GTK paths and safely migrates `~/Downloads`
- `configure_gnome` applies GNOME settings from the active desktop session
- `setup_flameshot` configures the user-level Flameshot launcher and keybindings

## Validation

Recommended checks:

```bash
ansible-playbook --syntax-check playbook.yml
yamllint .
ansible-lint
./tests/run.sh
```

## Notes

- The inventory targets localhost only.
- Adding a user to the `docker` group is effectively root-equivalent on Linux. Keep `docker_add_user_to_group` enabled only if that tradeoff is acceptable.
- Signal still uses the vendor-provided repository stanza with `xenial`. Keep that under periodic review in case the vendor changes its supported repository format.
