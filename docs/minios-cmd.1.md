% MINIOS-CMD(1) MiniOS Command-Line Builder
% MiniOS Development Team
% October 2025

# NAME

minios-cmd - command-line utility for configuring and building customized MiniOS system images

# SYNOPSIS

**minios-cmd** [*OPTIONS*]

# DESCRIPTION

**minios-cmd** is a command-line utility designed to simplify the process of configuring and building customized MiniOS system images. Acting as a frontend for **minios-live**(1), it manages the configuration and invokes **minios-live** to execute the actual build steps.

## Build Options

With **minios-cmd**, you can customize various aspects of your MiniOS image, including:

- **Distribution:** Choose from Debian releases (**buster**, **bullseye**, **bookworm**, **trixie**) and Ubuntu releases (**jammy**, **noble**)
- **Architecture:** Specify the target architecture (**amd64**, **i386** for older distributions)
- **Desktop Environment:**
  - **Debian:** **xfce** (standard), **flux** (minimum), **lxqt** (bookworm/trixie only)
  - **Ubuntu:** **xfce** only
- **Package Variant:**
  - **All Debian:** **standard** (xfce), **minimum** (flux)
  - **Bookworm/Trixie only:** **toolbox**, **ultra**
  - **Ubuntu:** **standard** only
- **Compression Type:** Specify the image compression method (**zstd**)
- **Kernel:** Configure kernel type, enable AUFS support, and DKMS module compilation
- **Locale and Timezone:** Set the system locale and timezone with multilingual support

# OPTIONS

## Configuration Options

**\-\-config-file** *FILE*
:   Specify the configuration file path. All other options are ignored.

**\-\-config-only**
:   Generate the configuration file only and do not start the build process.

## Build Options

**-b**, **\-\-build-dir** *DIR*
:   Specify the build directory.

## System Options

These options **must be provided** unless a configuration file is used:

**-d**, **\-\-distribution** *NAME*
:   Specify the distribution name (e.g., 'bookworm'). **REQUIRED**

**-a**, **\-\-architecture** *NAME*
:   Specify the architecture (e.g., 'amd64'). **REQUIRED**

**-de**, **\-\-desktop-environment** *NAME*
:   Specify the desktop environment (e.g., 'xfce'). **REQUIRED**

**-pv**, **\-\-package-variant** *NAME*
:   Specify the package variant (e.g., 'standard'). **REQUIRED**

**-c**, **\-\-compression-type** *NAME*
:   Specify the compression type (e.g., 'zstd').

## Kernel Options

**-kf**, **\-\-kernel-flavour** *NAME*
:   Specify the kernel flavour (e.g., 'none').

**-aufs**, **\-\-kernel-aufs**
:   Enable AUFS support in the kernel.

**-dkms**, **\-\-kernel-build-dkms**
:   Enable compilation of additional drivers during kernel installation.

## Locale and Timezone Options

**-l**, **\-\-locale** *NAME*
:   Specify the system locale (e.g., 'en_US').

**-ml**, **\-\-multilingual**
:   Enable multilingual support.

**-kl**, **\-\-keep-locales**
:   Keep all available locales.

**-tz**, **\-\-timezone** *NAME*
:   Specify the timezone (e.g., 'Etc/UTC').

## Boot Loader Options

**-ib**, **\-\-initramfs-builder** *NAME*
:   Specify the initramfs builder ('livekit' or 'dracut').

## Boot Menu Options

**-mln**, **\-\-menu-language** *NAME*
:   Specify the boot menu language ('multilang' for language selection or specific language code like 'ru_RU').

# DEFAULT SETTINGS

## Kernel Settings

**KERNEL_FLAVOUR**: "none"

## Locale & Timezone Settings

**LOCALE**: "en_US"
**LIVE_TIMEZONE**: "Etc/UTC"

## Boot Loader Settings

**INITRAMFS_BUILDER**: "dracut"

## Boot Menu Settings

**MENU_LANG**: "multilang"

# INTERACTION WITH MINIOS-LIVE

**minios-cmd** prepares the build environment and generates a **build.conf** configuration file based on the options provided. It then calls **minios-live** with the relevant environment variables, delegating the build execution to **minios-live**.

# EXAMPLES

Create a MiniOS Standard system image with default settings:

    minios-cmd -d bookworm -a amd64 -de xfce -pv standard -c zstd -aufs -dkms -kl

Create a MiniOS Toolbox system image with default settings:

    minios-cmd -d bookworm -a amd64 -de xfce -pv toolbox -c zstd -aufs -dkms -kl

Create a system image with Russian locale:

    minios-cmd -d bookworm -a amd64 -de xfce -pv toolbox -l ru_RU

Create a system image with LXQt desktop environment:

    minios-cmd -d bookworm -a amd64 -de lxqt -pv standard

Create a system image for 32-bit architecture:

    minios-cmd -d buster -a i386 -de xfce -pv standard

Create a system image with Ubuntu Jammy:

    minios-cmd -d jammy -pv standard -a amd64 -de xfce

Enable multilingual support (generates locales for English, Spanish, German, French, Italian, Portuguese, Brazilian Portuguese, Russian, and Indonesian):

    minios-cmd -d trixie -a amd64 -de xfce -pv standard -ml

Create a system image with Russian boot menu language:

    minios-cmd -d bookworm -a amd64 -de xfce -pv standard -mln ru_RU

Create a system image with livekit initramfs builder (smaller size):

    minios-cmd -d bookworm -a amd64 -de flux -pv standard -ib livekit

# GENERATING AND USING CONFIGURATION FILES

Generate a configuration file:

    minios-cmd --config-only --config-file myconfig.conf -d bookworm -a amd64 -de xfce -pv standard

Use the configuration file with **minios-live**:

    BUILD_CONF=/path/to/myconfig.conf minios-live -

or:

    export BUILD_CONF=/path/to/myconfig.conf
    minios-live -

# SEE ALSO

**minios-live**(1), **condinapt**(1), **condinapt-minios**(7)

# AUTHORS

MiniOS Development Team <https://minios.dev>
