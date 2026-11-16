# Repository findings

This file records the outcome of the workstation-bootstrap cleanup. The playbook is still a local Ubuntu GUI session bootstrap, split into a privileged system play and an unprivileged user play.

## Fixed

- The privileged play included `preflight` twice. It now includes that role once. The user play still includes it once.
- `roles/install_displaylink_repo` was unused. DisplayLink stays in `apt_packages`, which can take a checksum.
- `.env` was tracked, held this workstation's Git identity, and was never loaded. It is removed from the index and ignored. Ansible reads `.env.yml`.
- `XDG_DOWNLOAD_DIR` pointed at the parent of the synced Downloads directory. It now uses `xdg_download_dir`, the same path as the `~/Downloads` symlink.
- Downloads migration uses `mv -n`. If a destination name already exists, the play fails and does not delete the leftover files.
- Resilio Sync now uses LinuxServer `3.1.2` with digest `sha256:2e8e4b1dc34336e67effe28600e61888b1332b5241b8185958342b7e6df62d65`. The official `resilio/sync` image has no version tag newer than `2.8.1`, and that tag is the same digest as its `latest` tag. The listen port is published on `55555/tcp` and `55555/udp`. Host directories are created first. The memory value is a real Docker limit of `512m`.
- OpenCode installs `@opencode/cli` `2.3.0` with npm. The config is the native OpenCode 2 shape, the code-reviewer model id matches `xai/grok-code-fast-1`, and provider URLs come from `opencode_provider_base_url`.
- TokenScope `2.1.0` supports OpenCode 2, so the plugin stays and is pinned. The OpenCode 1 command file is removed because OpenCode 2 registers `/tokenscope`.
- `community.general` is pinned to `14.0.1`. Snap installs use integer revisions recorded on 2026-11-14, and snapd holds those revisions against automatic refresh.
- The Signal repository stanza stays on `xenial` because that is still the vendor suite. The README records the Ubuntu 24.04 `update-manager` caveat.
- `synaptics_repository_keyring_deb_checksum` stays empty. Synaptics does not publish a checksum, and a hash from one download is not a vendor attestation.
- `docker_add_user_to_group` stays `true`. The README states that this is root-equivalent and that `.env.yml` can set it to `false`.

## Left unchanged on purpose

`.env` remains in older commits. Removing it from history requires a rewrite and a force-push. This change does not do that.

An existing Resilio identity created by the official `resilio/sync` image is not imported into the LinuxServer layout. Files already on disk are not deleted.
