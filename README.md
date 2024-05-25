# Ansible Playbook: Move-In Using Ansible

## Overview

This Ansible playbook automates the setup and configuration of a new Linux environment, installing various applications and configuring system settings. Below is a high-level overview of each role included in the playbook and their responsibilities.

## Roles

### 1. `apt_packages`
This role installs necessary APT packages to ensure the system has all required software and dependencies.

### 2. `install_applications`
This role installs a list of specified applications to set up the user's environment with essential tools.

### 3. `setup_docker`
This role sets up Docker on the system, enabling the Docker service and adding the user to the Docker group.

### 4. `install_joplin`
This role installs Joplin, a note-taking application, to help manage notes and to-do lists.

### 5. `install_zoom`
This role installs Zoom, a video conferencing application, for online meetings and communications.

### 6. `install_rambox`
This role installs Rambox, a messaging application, to centralize various messaging platforms.

### 7. `setup_resilio_sync`
This role sets up Resilio Sync using Docker to enable file synchronization across devices.

### 8. `create_directories`
This role creates necessary directories as specified in the configuration to organize the file system.

### 9. `configure_git`
This role configures Git settings such as `user.email` and `user.name` for version control.

### 10. `update_user_dirs`
This role updates user directory configurations, including setting up the correct locations for user directories like Downloads.

### 11. `configure_gnome`
This role configures GNOME settings to customize the desktop environment according to user preferences.

### 12. `setup_flameshot`
This role sets up Flameshot, a screenshot tool, ensuring it is installed and properly configured with custom keybindings and autostart settings.

## Usage

To use this playbook, run the following command in your terminal:

```bash
ansible-pull -U https://github.com/jonhowe/move-in-using-ansible playbook.yml --ask-become-pass
```
