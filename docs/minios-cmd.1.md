% MINIOS-CMD(1) MiniOS Command-Line Builder
% MiniOS Development Team
% September 2026

# NAME

minios-cmd - configure and build a MiniOS image

# SYNOPSIS

**minios-cmd** [*OPTIONS*]

# DESCRIPTION

**minios-cmd** is a command-line frontend for **minios-live**(1). It copies a configuration template or an existing configuration into a work directory, applies frontend values, and runs a complete build.

The default configuration currently lists Debian **buster**, **bullseye**, **bookworm**, and **trixie**; Ubuntu **bionic**, **focal**, **jammy**, **noble**, and **resolute**; and Devuan **beowulf**, **chimaera**, **daedalus**, and **excalibur**. It lists **amd64**, **i386**, and **i386-pae** architectures; **core**, **flux**, **xfce**, and **lxqt** environments; **minimum**, **standard**, **toolbox**, and **ultra** variants; and **xz**, **lzo**, **gz**, **lz4**, and **zstd** compression.

Not every combination is necessarily available. The current configuration, environment links, and repositories determine what can be built.

# REQUIREMENTS

All non-help operations, including **\-\-config-only**, currently require root. Source-tree builds require a Debian or Ubuntu host, the packages in **linux-live/prerequisites.list**, and repository access. The default template enables apt-cacher-ng at **127.0.0.1:3142**; run it or set **USE_APT_CACHER=false** in the generated configuration.

# OPTIONS

Without **\-\-config-file**, the distribution, architecture, desktop environment, and package variant options are required.

## Configuration Options

**\-\-config-file** *FILE*
:   In normal mode, copy *FILE* into the work directory as the base configuration, then write parsed frontend values and non-empty frontend defaults into that copy. With **\-\-config-only**, use *FILE* as the output path and overwrite it. To use a configuration without frontend merging, run **minios-live** directly with **BUILD_CONF**.

**\-\-config-only**
:   Generate a configuration file and do not build. Without **\-\-config-file**, the four required system options are required. Supplying an output path with **\-\-config-file** bypasses that check, and omitted target fields retain template values.

**-b**, **\-\-build-dir** *DIR*
:   Use *DIR* as the build directory.

## System Options

**-d**, **\-\-distribution** *NAME*
:   Set the target distribution. Required without **\-\-config-file**.

**-a**, **\-\-architecture** *NAME*
:   Set the target architecture. Required without **\-\-config-file**.

**-de**, **\-\-desktop-environment** *NAME*
:   Set the desktop environment. Required without **\-\-config-file**.

**-pv**, **\-\-package-variant** *NAME*
:   Set the package variant. Required without **\-\-config-file**.

**-c**, **\-\-compression-type** *NAME*
:   Set SquashFS compression. Default: **zstd**.

## Kernel Options

**-kp**, **\-\-kernel-provider** *NAME*
:   Select **distribution** or **minios**.

**-kf**, **\-\-kernel-flavour** *NAME*
:   Set the kernel flavour, such as **none**, **rt**, or **cloud**.

**-mk**, **\-\-minios-kernel**
:   Select the MiniOS kernel provider.

**-mks**, **\-\-minios-kernel-series** *NAME*
:   Select **auto**, **6.1**, or **6.12** and use the MiniOS provider.

**-kpm**, **\-\-kernel-payload-mode** *NAME*
:   Select **runtime** or **full**.

**-dkms**, **\-\-kernel-build-dkms**
:   Build additional DKMS drivers.

**-aufs**, **\-\-kernel-aufs**
:   Deprecated alias for **\-\-minios-kernel**.

## Locale And Boot Options

**-l**, **\-\-locale** *NAME*
:   Set the system locale. Default: **en_US**.

**-ml**, **\-\-multilingual**
:   Generate all locales declared by **minioslib**.

**-kl**, **\-\-keep-locales**
:   Retain all available locales instead of pruning them.

**-tz**, **\-\-timezone** *NAME*
:   Set the timezone. Default: **Etc/UTC**.

**-ib**, **\-\-initramfs-builder** *NAME*
:   Select **livekit** or **dracut**. Default: **dracut**.

**-mln**, **\-\-menu-language** *NAME*
:   Select **multilang** or a supported menu locale. Default: **multilang**.

## Ubuntu Pro Option

**\-\-ubuntu-pro-token** *TOKEN*
:   Attach an Ubuntu Pro subscription during a Bionic, Focal, Jammy, or Noble build. Other targets skip attachment with a warning. The builder detaches the subscription and removes the token from the final image. Command-line tokens may be visible in shell history or process listings.

# DEFAULTS

The frontend defaults are **COMP_TYPE=zstd**, **KERNEL_PROVIDER=distribution**, **KERNEL_FLAVOUR=none**, **MINIOS_KERNEL_SERIES=auto**, **KERNEL_PAYLOAD_MODE=runtime**, **KERNEL_BUILD_DKMS=false**, **LOCALE=en_US**, **MULTILINGUAL=false**, **KEEP_LOCALES=false**, **LIVE_TIMEZONE=Etc/UTC**, **INITRAMFS_BUILDER=dracut**, and **MENU_LANG=multilang**.

Trixie-based **i386** and **i386-pae** values select the MiniOS provider when the distribution and architecture are supplied to the frontend through options or the environment. Values present only inside **\-\-config-file** are not loaded before defaults are calculated. Frontend defaults may differ from values in the full **build.conf** template.

# EXAMPLES

Build a standard Bookworm Xfce image with frontend defaults:

    sudo minios-cmd -d bookworm -a amd64 -de xfce -pv standard

Build with a MiniOS kernel, DKMS drivers, and retained locales:

    sudo minios-cmd -d bookworm -a amd64 -de xfce -pv toolbox -mk -dkms -kl

Build a multilingual image:

    sudo minios-cmd -d trixie -a amd64 -de xfce -pv standard -ml

Build the Flux minimum variant with livekit:

    sudo minios-cmd -d bookworm -a amd64 -de flux -pv minimum -ib livekit

Generate or overwrite a configuration file:

    sudo minios-cmd --config-only --config-file ./myconfig.conf \
      -d bookworm -a amd64 -de xfce -pv standard

Use the file without frontend merging:

    sudo BUILD_CONF=/absolute/path/myconfig.conf minios-live -

# SEE ALSO

**minios-live**(1), **condinapt**(1), **condinapt-minios**(7)

# AUTHORS

MiniOS Development Team <https://minios.dev>
