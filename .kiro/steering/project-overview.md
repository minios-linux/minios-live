# MiniOS Live Build System - Project Overview

## Project Purpose

MiniOS Live (`minios-live`) is a comprehensive build system for creating bootable MiniOS ISO images. MiniOS is a portable Debian/Ubuntu-based Linux distribution with a graphical interface, designed for reliability and ease of use.

## Key Components

### Main Scripts
- `minios-live` - Step-by-step build orchestrator with command range support
- `minios-cmd` - CLI frontend for simplified configuration and building
- `linux-live/minioslib` - Core library with shared functions
- `linux-live/condinapt` - Conditional package installer with filter support

### Build Configuration
- `linux-live/build.conf` - Main configuration file with all build parameters
- `linux-live/condinapt.map` - Filter prefix to variable mappings for package conditions

### Directory Structure
```
linux-live/
├── aptsources/          # APT source lists per distribution
├── bootfiles/           # Boot loader files (GRUB, SYSLINUX)
├── environments/        # Desktop environment module symlinks
│   ├── core/           # Minimal kernel-only
│   ├── flux/           # Fluxbox minimal desktop
│   ├── lxqt/           # LXQt desktop
│   └── xfce/           # Xfce desktop (default)
├── initramfs/          # Initramfs builders
│   ├── dracut-mos/     # Dracut-based initramfs
│   └── livekit-mos/    # Livekit-based initramfs (smaller)
└── scripts/            # Module build scripts
    ├── 00-core/        # Base system packages
    ├── 01-kernel/      # Kernel installation
    ├── 02-firmware/    # Hardware firmware
    ├── 03-gui-base/    # GUI base libraries
    ├── 04-*-desktop/   # Desktop environments
    ├── 05-apps/        # Applications
    └── 10-*/           # Additional modules
```

## Supported Configurations

### Distributions
- Debian: buster (10), bullseye (11), bookworm (12), trixie (13), sid
- Ubuntu: jammy (22.04), noble (24.04)

### Desktop Environments
- xfce (default, all distributions)
- flux (minimal Fluxbox)
- lxqt (bookworm/trixie only)

### Package Variants
- minimum - Minimal system
- standard - Standard desktop
- toolbox - System administration tools
- ultra - Full-featured with Docker

### Architectures
- amd64 (primary)
- i386 (older distributions)

## Build Process

The build follows these stages (in order):
1. `build-bootstrap` - Debootstrap minimal base system
2. `build-chroot` - Install packages in chroot environment
3. `build-live` - Create core SquashFS image
4. `build-modules` - Build additional SquashFS modules
5. `build-boot` - Generate initrd and boot configuration
6. `build-config` - Generate system configuration files
7. `build-iso` - Create final ISO image
8. `remove-sources` - Cleanup source files

## Key Technologies

- SquashFS for compressed read-only filesystem modules
- AUFS/OverlayFS for layered filesystem support
- Dracut or Livekit for initramfs generation
- GRUB and SYSLINUX for boot loading
- CondinAPT for conditional package management
