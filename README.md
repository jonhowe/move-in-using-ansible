# Ansible Playbook: Move-In Using Ansible

This repository bootstraps an Ubuntu workstation after login. It is intended to run on the local machine inside the active GUI session, not from a headless shell.

## What this playbook does

- installs baseline APT packages
- adds third-party APT repositories with `signed-by` keyrings
- installs desktop applications from APT or from pinned Snap revisions
- enables Docker and optionally adds the logged-in user to the `docker` group
- runs Resilio Sync 3.1.2 in Docker
- configures Git, XDG user directories, GNOME settings, Ghostty, and Flameshot
- installs optional Python CLI tools with `pipx`
- installs the OpenCode 2 CLI and a managed `opencode.json`

## Safety and behavior changes

- The playbook fails fast if it is not running on local Ubuntu or if no GUI session is present.
- Local overrides are loaded from `.env.yml` if the file exists.
- Existing files in `~/Downloads` are never deleted silently.
  - If files are present and `downloads_migrate_existing` is true, they are moved into the synced Downloads directory first.
  - A name that already exists at the destination is left in place, and the play fails before the directory is removed.
  - If migration is disabled and `~/Downloads` contains data, the play fails instead of deleting it.
- `XDG_DOWNLOAD_DIR` and the `~/Downloads` symlink both point at the synced Downloads directory.
- Joplin, Todoist, Zoom, and Rambox install from pinned Snap revisions. A pinned revision is held against snapd's automatic refresh.
- Python packages are installed with `pipx` instead of system `pip`.
- OpenCode 2 installs from the pinned npm package `@opencode/cli`, not from a remote shell script.

## Requirements

Run this as the logged-in desktop user on Ubuntu 26.04. The package list uses the 26.04 names `fastfetch` and `docker-compose-v2`.

Stop unless all of these are true:

- `/etc/os-release` says Ubuntu 26.04.
- The process has `DISPLAY` or `WAYLAND_DISPLAY`, plus `XDG_RUNTIME_DIR`. Preflight rejects a headless or SSH shell.
- The user can `sudo`.
- The machine can reach GitHub, the Ubuntu archives, Snapcraft, and the container registry.

The playbook does not install Git, Ansible, or the Docker SDK. Install those first. `community.general` 14.0.1 needs `ansible-core` 2.19 or newer. The Ubuntu 26.04 `ansible` package brings 2.20. `python3-docker` is what the Resilio tasks import. Without it, `docker_container` fails even though the playbook installs Docker itself.

The repository is public. Clone it over HTTPS. An SSH key is not required.

## First run

`bootstrap.sh` performs the steps below. On a machine that does not have the checkout yet:

```bash
curl -fsSL -o /tmp/move-in-bootstrap.sh https://raw.githubusercontent.com/jonhowe/move-in-using-ansible/main/bootstrap.sh
bash /tmp/move-in-bootstrap.sh
```

From an existing checkout, run `./bootstrap.sh`. Set `GIT_USER_NAME` and `GIT_USER_EMAIL` together to write a new `.env.yml`. Set `OPENCODE_PROVIDER_BASE_URL` when the provider is not the tracked default. An existing `.env.yml` is left unchanged. Set `ANSIBLE_BECOME_PASS` in the same process for non-interactive sudo. The script does not write that password down. `MOVE_IN_REPO_DIR` changes the clone destination. The default is `~/git/move-in-using-ansible`.

Install the three missing tools:

```bash
sudo apt-get update
sudo apt-get install -y git ansible python3-docker
```

Clone the repository and stay in that directory. Later commands need `ansible.cfg` and `inventory` from there.

```bash
mkdir -p "$HOME/git"
git clone https://github.com/jonhowe/move-in-using-ansible.git "$HOME/git/move-in-using-ansible"
cd "$HOME/git/move-in-using-ansible"
```

Create `.env.yml` only for values that differ from [`vars/main.yml`](vars/main.yml). Do not copy `user`, `group`, or `home_directory` from [`.env.yml.example`](.env.yml.example). Those lookups already follow `USER` and `HOME`, and the example value `yourusername` makes preflight fail.

```yaml
---
git_user_name: Example User
git_user_email: user@example.com
```

Add `opencode_provider_base_url` only when the OpenCode provider is not `http://127.0.0.1:4001/v1`. Leave `.env.yml` untracked.

Install collections. `community.general` is pinned to 14.0.1 because snap revision installs need that collection's `revision` parameter. `community.docker` is unpinned and installs the current release.

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Run the playbook. A sudo timestamp is not enough: the run takes longer than the default 15-minute cache, mostly while installing snaps. For a non-interactive run, export `ANSIBLE_BECOME_PASS` in that same process and omit `--ask-become-pass`. Do not write the password into the repo, a file, or the command line.

```bash
ansible-playbook playbook.yml --ask-become-pass
```

Success is a recap with `failed=0`. Resilio should answer at `http://127.0.0.1:8888`, and `~/.local/bin/opencode --version` should print `2.3.0`.

The `docker` group change applies to new logins only. Terminals that were already open still get "permission denied" from the Docker socket until the user logs out and back in.

Run a subset with tags:

```bash
ansible-playbook playbook.yml --ask-become-pass --tags "base,apps"
```

## Configuration

Tracked defaults live in [`vars/main.yml`](vars/main.yml).

`.env.yml` is YAML, not dotenv syntax. That is intentional so nested Ansible variables remain easy to override. Replacing a list replaces the whole list. [`.env.yml.example`](.env.yml.example) shows the override shapes. Copy a key into `.env.yml` only when its value must change.

Common overrides:

- `git_user_name`, `git_user_email`
- `docker_add_user_to_group`
- `downloads_migrate_existing`
- `pipx_packages`
- `opencode_provider_base_url`
- `opencode_npm_version`
- `optional_snap_applications`
- `user`, `group`, `home_directory`, only when they must differ from the logged-in user

## Roles

- `preflight` validates Ubuntu, local execution, the logged-in GUI session, and key variables
- `install_applications` manages third-party APT repositories and pinned Snap installs
- `apt_packages` installs core Ubuntu packages and the Synaptics keyring package for DisplayLink when needed
- `install_node_tools` installs npm packages that are shared by the system, including the Codex CLI
- `setup_docker` starts Docker and optionally adds the logged-in user to the `docker` group
- `setup_resilio_sync` starts the Resilio Sync container
- `create_directories` creates the standard workstation directories
- `configure_git` writes Git identity into the logged-in user's global Git config
- `install_python_tools` installs optional user CLI tools with `pipx`
- `configure_opencode` installs OpenCode 2 for the logged-in user and writes `opencode.json`
- `update_user_dirs` sets XDG and GTK paths and safely migrates `~/Downloads`
- `configure_gnome` applies GNOME settings, favorite apps, the terminal profile, and Ghostty
- `setup_flameshot` configures the user-level Flameshot launcher and keybindings

## OpenCode

`configure_opencode` installs `@opencode/cli` at the version in `opencode_npm_version` under `~/.local`. The managed config is OpenCode 2 native shape. Both custom providers use `opencode_provider_base_url`.

TokenScope is pinned to `@ramtinj95/opencode-tokenscope@2.1.0`. OpenCode 2 registers `/tokenscope` itself. The role removes a leftover OpenCode 1 command file at `~/.config/opencode/command/tokenscope.md`. A rerun overwrites `opencode.json`.

## Resilio Sync

The image is `lscr.io/linuxserver/resilio-sync:3.1.2` with its digest pinned. That is the newest published version tag. The `latest` tag is not used. The official `resilio/sync` image stops at 2.8.1.

The container publishes the web UI on `127.0.0.1:8888` and the Sync listen port on `55555/tcp` and `55555/udp`. Host directories are created before the container starts:

- `~/storage/btsync/config` mounted at `/config`
- `~/storage/btsync/folders` mounted at `/sync`
- `~/storage/btsync/folders/Downloads` mounted at `/downloads`

The memory cap defaults to `512m` and is overridable with `resilio_sync.mem_limit`. An identity created by the older official image is not imported. Re-link shares if this machine already has one. Existing files under the storage directory are left in place.

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
- Adding a user to the `docker` group is effectively root-equivalent on Linux. Keep `docker_add_user_to_group` enabled only if that tradeoff is acceptable. Set it to `false` in `.env.yml` to refuse the membership.
- Signal still uses the vendor repository stanza with `xenial`. That stanza has caused `update-manager` dependency errors on Ubuntu 24.04. Change it when Signal publishes a newer suite.
- Synaptics does not publish a checksum for the DisplayLink keyring package. `synaptics_repository_keyring_deb_checksum` stays empty unless an override supplies a vendor checksum.
- Snap revisions were recorded on 2026-11-14. Change the integer in `vars/main.yml` or `.env.yml` to move a snap forward. `snap refresh <name>` bypasses the hold.
- `.env` is ignored and is not loaded. Older commits still contain a previous copy. Purging it from history requires a rewrite and a force-push, which this repository does not do.
