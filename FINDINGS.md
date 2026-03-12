# Repository Findings

## Current state

This repository has been remediated from the earlier review and now follows a safer structure for Jon's Ubuntu desktop bootstrap workflow.

The most important changes already applied are:

- split execution into a privileged system play and a logged-in GUI user play
- added a `preflight` role that enforces local Ubuntu plus an active GUI session
- added optional local overrides through `.env.yml`
- replaced direct-download installers for Joplin, Zoom, and Rambox with Snap-based installs
- removed system `pip` usage and switched optional Python CLI installs to `pipx`
- made `~/Downloads` migration non-destructive and user-visible
- removed insecure global Ansible defaults such as disabled host key checking and repo-root log output

## Files that define the new execution model

- [playbook.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/playbook.yml)
- [roles/preflight/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/preflight/tasks/main.yml)
- [vars/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/vars/main.yml)
- [.env.yml.example](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/.env.yml.example)

## What was remediated

### 1. GUI-session correctness

Status:
- Remediated

Changes:
- The playbook now has a separate user-session play with `become: false`.
- `preflight` asserts:
  - local execution
  - Ubuntu/Debian-family target
  - configured user matches the active login session
  - GUI session variables are present before desktop customization runs
- GUI-sensitive tasks now use a constructed `gui_session_environment`.

Primary references:
- [playbook.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/playbook.yml)
- [roles/preflight/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/preflight/tasks/main.yml)
- [roles/configure_gnome/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/configure_gnome/tasks/main.yml)

### 2. Override mechanism for machine-specific values

Status:
- Remediated

Changes:
- Tracked defaults remain in `vars/main.yml`.
- Untracked machine-specific overrides can now live in `.env.yml`.
- `.env.yml.example` documents the supported override pattern.

Primary references:
- [.env.yml.example](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/.env.yml.example)
- [.gitignore](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/.gitignore)

### 3. Python tooling

Status:
- Remediated

Changes:
- The old system `pip` workflow and `--break-system-packages` usage were removed.
- Base packages now install `pipx` and `python3-venv`.
- Optional Python CLI tools are managed through `community.general.pipx`.

Primary references:
- [vars/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/vars/main.yml)
- [roles/install_python_tools/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/install_python_tools/tasks/main.yml)

### 4. Downloads safety

Status:
- Remediated

Changes:
- Existing files in `~/Downloads` are now discovered before any replacement occurs.
- If content exists, the playbook prints a message and moves files into the synced Downloads directory.
- If migration is disabled, the playbook fails instead of deleting data.
- Only after migration or empty-directory confirmation does the symlink get created.

Primary references:
- [roles/update_user_dirs/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/update_user_dirs/tasks/main.yml)

### 5. Ansible configuration hygiene

Status:
- Remediated

Changes:
- Removed global `become` defaults from `ansible.cfg`.
- Removed disabled host key checking.
- Removed repo-root `ansible.log` configuration.
- Kept the config minimal and local-safe.

Primary references:
- [ansible.cfg](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/ansible.cfg)

### 6. Remote installer risk

Status:
- Mostly remediated

Changes:
- The previous direct-download flows for Joplin, Zoom, and Rambox were removed.
- Those apps are now installed through Snap roles with configurable settings in `vars/main.yml` or `.env.yml`.

Primary references:
- [roles/install_joplin/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/install_joplin/tasks/main.yml)
- [roles/install_zoom/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/install_zoom/tasks/main.yml)
- [roles/install_rambox/tasks/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/install_rambox/tasks/main.yml)

## Remaining risks and follow-up work

### 1. Residual: Resilio Sync container image is still not pinned to a tag or digest

Status:
- Open

Evidence:
- [vars/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/vars/main.yml#L53) still uses `resilio/sync` without an immutable tag or digest.

Why it matters:
- Container provenance and reproducibility are still weaker than ideal.

Recommended future remediation:
- Pin the image to an explicit tag or digest in `vars/main.yml` or `.env.yml`.
- If possible, use a digest and document the upgrade procedure.

### 2. Residual: Synaptics keyring checksum is supported but not populated

Status:
- Open

Evidence:
- [roles/apt_packages/defaults/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/roles/apt_packages/defaults/main.yml#L2) exposes `synaptics_repository_keyring_deb_checksum`, but the default is empty.

Why it matters:
- The task can verify integrity, but only if a trusted checksum is supplied.

Recommended future remediation:
- Add the vendor-published checksum in `.env.yml` or tracked defaults once verified.

### 3. Residual: Snap replaces direct downloads, but exact application versions are not pinned

Status:
- Open

Evidence:
- [vars/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/vars/main.yml#L126) defines Joplin, Zoom, and Rambox through Snap channels rather than explicit versions.

Why it matters:
- This is safer than raw script or `.deb` downloads, but it is not fully reproducible.

Recommended future remediation:
- If exact version pinning becomes important, define a stricter application packaging strategy per app and document support expectations.

### 4. Residual: Signal repository stanza still uses `xenial`

Status:
- Open

Evidence:
- [vars/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/vars/main.yml#L14) still uses the vendor repository format with `xenial`.

Why it matters:
- It may still be valid, but it should be periodically re-checked against current vendor guidance.

### 5. Residual: Docker group membership remains a conscious security tradeoff

Status:
- Open by design

Evidence:
- [vars/main.yml](/home/jhowe/move-in-using-ansible-main-updated-reviewed-fixed3/move-in-using-ansible-main/vars/main.yml#L8) defaults `docker_add_user_to_group: true`.

Why it matters:
- Local Docker group membership is effectively root-equivalent.

Recommended future remediation:
- Leave it configurable.
- Disable it in `.env.yml` if Jon prefers stricter host security.

## Recommended next remediation order

1. Pin the Resilio Sync image tag or digest.
2. Populate `synaptics_repository_keyring_deb_checksum` with a verified value.
3. Decide whether Snap-based desktop apps are acceptable long-term or whether any app should move to a more tightly pinned packaging path.
4. Re-check the Signal vendor repository format.

## Verification notes

- `ansible-playbook --syntax-check playbook.yml` parsed successfully in this environment.
- The environment emitted plugin-load permission warnings during syntax check because of sandbox restrictions, so this was only a limited validation pass.
- `ansible-lint` and `yamllint` were not available in the current environment, so lint validation was not executed here.
