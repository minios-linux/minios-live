% CONDINAPT-MINIOS(7) MiniOS CondinAPT Integration
% MiniOS Development Team
% October 2025

# NAME

condinapt-minios - CondinAPT integration in the MiniOS build system

# DESCRIPTION

This document describes the specific aspects of using **condinapt**(1) in the MiniOS build system.

For basic CondinAPT features, see **condinapt**(1).

# INTEGRATION WITH MINIOS BUILD SYSTEM

## Usage in MiniOS Modules

CondinAPT is a standard tool for package installation in MiniOS modules. It integrates into the build process through the standard module interface.

In the module installation script (**install**):

    #!/bin/bash
    set -e

    # Load MiniOS library
    . /minioslib || exit 1

    # Install packages via CondinAPT
    /usr/share/minios-live/condinapt \
        -l "$CWD/packages.list" \
        -c /etc/minios-live/build.conf \
        -m /usr/share/minios-live/condinapt.map

## MiniOS Module Structure

Each module in **/usr/share/minios-live/scripts/** follows a standardized structure:

    XX-module-name/
    ├── packages.list                     # Package list with conditions
    ├── install                           # Installation script (uses CondinAPT)
    ├── rootcopy-install/                 # (optional) Files to copy
    └── rootcopy-postinstall/             # (optional) Files after installation

# MINIOS CONFIGURATION

## Filter Mapping

Contents of **condinapt.map** in MiniOS:

    d=DISTRIBUTION
    da=DISTRIBUTION_ARCH
    dt=DISTRIBUTION_TYPE
    de=DESKTOP_ENVIRONMENT
    pv=PACKAGE_VARIANT
    ik=INSTALL_KERNEL
    kf=KERNEL_FLAVOUR
    ka=KERNEL_AUFS
    kbd=KERNEL_BUILD_DKMS
    lo=LOCALE
    ml=MULTILINGUAL
    kl=KEEP_LOCALES

## Configuration Variables

Main variables from **build.conf**:

**DISTRIBUTION**
:   Target distribution (bookworm, trixie, jammy, noble)

**DISTRIBUTION_ARCH**
:   Architecture (amd64, i386, i386-pae)

**DESKTOP_ENVIRONMENT**
:   Desktop environment (core, flux, xfce, lxqt)

**PACKAGE_VARIANT**
:   Package variant (minimum, standard, toolbox, ultra)

**INSTALL_KERNEL**
:   Install kernel package (true/false)

**KERNEL_FLAVOUR**
:   Kernel flavour (none, rt, cloud)

**KERNEL_AUFS**
:   AUFS support (true/false)

**KERNEL_BUILD_DKMS**
:   Build DKMS modules (true/false)

**LOCALE**
:   System locale (C, en_US, ru_RU, es_ES, pt_BR)

**MULTILINGUAL**
:   Multilingual support (true/false)

**KEEP_LOCALES**
:   Keep locales (true/false)

## Automatically Calculated Variables

From **minioslib**:

**DISTRIBUTION_TYPE**
:   Distribution type (debian, ubuntu) - automatically determined based on DISTRIBUTION

    - **legacy**: stretch, buster, orel, bionic
    - **current**: bullseye, bookworm, focal, jammy, noble
    - **future**: trixie, kali-rolling, sid

# EXAMPLES

## Multimedia Module

**packages.list:**

    # Basic multimedia codecs - always
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good

    # Additional codecs - not for minimal variant
    gstreamer1.0-plugins-bad -pv=minimum
    gstreamer1.0-plugins-ugly -pv=minimum
    gstreamer1.0-libav -pv=minimum

    # Professional tools - only for toolbox and ultra
    audacity +{pv=toolbox|pv=ultra}
    kdenlive +{pv=toolbox|pv=ultra} +{de=xfce|de=lxqt}
    ---
    # Distribution-specific packages from backports
    ffmpeg @bookworm-backports +d=bookworm

## Driver Module

**packages.list:**

    # Basic drivers
    mesa-utils
    xserver-xorg-video-all

    # NVIDIA drivers - only for non-free distributions
    nvidia-driver +d=bookworm -{pv=minimum&de=core}

    # AMD drivers - for modern distributions
    firmware-amd-graphics +{d=trixie|d=noble}
    mesa-vulkan-drivers +{d=trixie|d=noble}

    # Old drivers - for old systems
    xserver-xorg-video-radeon +d=bookworm

## Localization Module

**packages.list:**

    # Basic locales - always
    locales

    # Russian localization
    language-pack-ru +lo=ru_RU
    fonts-liberation +lo=ru_RU
    firefox-esr-l10n-ru +lo=ru_RU +{de=xfce|de=lxqt}

    # Multilingual support
    task-russian +ml=true +lo=ru_RU
    hunspell-ru +ml=true +lo=ru_RU

    # Keeping locales
    vlc-l10n +kl=true +{pv=toolbox|pv=ultra}

    # Regional settings for different locales
    language-pack-pt +lo=pt_BR
    language-pack-de +lo=de_DE
    language-pack-fr +lo=fr_FR

## Advanced Filter Usage

**packages.list:**

    # DKMS modules with kernel and distribution conditions
    ntfs3-dkms -ka=true -d=buster -d=trixie -d=sid
    zfs-dkms +{pv=toolbox|pv=ultra} +da=amd64 +kbd=true -kf=none

    # Drivers for old systems
    broadcom-sta-dkms -d=jammy -ka=true -da=i386
    aufs-dkms +dt=debian +d=buster

    # Exclusion for new distributions
    realtek-rtl8821cu-dkms -d=trixie -d=sid
    firmware-b43-installer -d=bionic

    # Complex alternatives with filters
    exfatprogs -pv=minimum || exfat-utils -pv=minimum && exfat-fuse -pv=minimum

    # Localization with exclusions and conditions
    vlc-l10n -lo=en_US +{pv=toolbox|pv=ultra}
    language-pack-gnome-ru-base +lo=ru_RU +dt=ubuntu
    language-pack-gnome-ru-base +ml=true +dt=ubuntu
    language-pack-gnome-ru-base +kl=true +dt=ubuntu

## Optimization for MiniOS

Grouping by functionality:

    #=== Core System ===
    systemd +pv=standard +pv=toolbox +pv=ultra
    dbus

    #=== Desktop Environment ===
    xfce4-panel +de=xfce
    lxqt-panel +de=lxqt
    fluxbox +de=flux

    #=== Applications by Variant ===
    firefox-esr +{pv=standard|pv=toolbox|pv=ultra}
    thunderbird +{pv=toolbox|pv=ultra}
    libreoffice +pv=ultra

# INTEGRATION WITH BUILD PROCESS

## Module Environment Variables

Within the MiniOS module context, the following variables are available:

**$CWD**
:   Current module directory

**$LIVEKITNAME**
:   System name (usually "minios")

**$MODULE**
:   Current module name

## Using minioslib

Example installation script with conditional execution:

    #!/bin/bash
    set -e

    # Load MiniOS library
    . /minioslib || exit 1

    # Check module conditions
    if [ "$PACKAGE_VARIANT" = "minimum" ] && [ "$DESKTOP_ENVIRONMENT" = "core" ]; then
        echo "Skipping module for minimal core build"
        exit 0
    fi

    # Install packages
    /usr/share/minios-live/condinapt \
        -l "$CWD/packages.list" \
        -c /etc/minios-live/build.conf \
        -m /usr/share/minios-live/condinapt.map

# FILES

**/etc/minios-live/build.conf**
:   Main MiniOS build configuration file

**/usr/share/minios-live/condinapt.map**
:   Filter mapping for MiniOS build system

**/usr/share/minios-live/scripts/XX-module-name/packages.list**
:   Package list for each module

**/usr/share/minios-live/scripts/XX-module-name/install**
:   Module installation script

# SEE ALSO

**condinapt**(1), **minios-live**(1), **minios-cmd**(1)

# AUTHORS

MiniOS Development Team <https://minios.dev>
