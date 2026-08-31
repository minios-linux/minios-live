% CONDINAPT-MINIOS(7) MiniOS CondinAPT Integration
% MiniOS Development Team
% September 2026

# NAME

condinapt-minios - use CondinAPT in MiniOS build modules

# DESCRIPTION

MiniOS modules use **condinapt**(1) to select and install APT packages from the active build configuration. This page documents the MiniOS staging paths, module layout, and standard filter map.

# MODULE INTEGRATION

The builder discovers modules through the selected environment directory:

    linux-live/environments/<desktop>/

Entries there are normally links to reusable module sources under:

    linux-live/scripts/<NN-module-name>/

During the install stage, the builder copies the module's **install** script to **/install** in the chroot. It also stages **condinapt**, **condinapt.map**, **packages.list**, and the generated build configuration at the chroot root. Do not rely on **$CWD** or an installed **/usr/share/minios-live** path from inside a module script.

A minimal **install** script is:

    #!/bin/bash
    set -e
    set -o pipefail
    set -u

    . /minioslib || exit 1
    . /minios_build.conf || exit 1

    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    /condinapt \
        -l "${SCRIPT_DIR}/packages.list" \
        -c "${SCRIPT_DIR}/minios_build.conf" \
        -m "${SCRIPT_DIR}/condinapt.map"

The standard module may contain:

    NN-module-name/
    |-- packages.list
    |-- install
    |-- skip_conditions.conf       # optional
    |-- rootcopy-install/          # optional
    |-- build                      # optional
    |-- patches/                   # optional, used by build
    |-- is_dkms_build              # optional DKMS marker
    |-- rootcopy-postinstall/      # optional
    `-- postinstall                # optional

See **linux-live/scripts/10-example/README.md** for the complete module lifecycle, ownership manifests, naming, and environment-link instructions.

# MINIOS FILTER MAP

The current **linux-live/condinapt.map** contains:

    d=DISTRIBUTION
    da=DISTRIBUTION_ARCH
    dp=DISTRIBUTION_PROFILE
    is=INIT_SYSTEM
    de=DESKTOP_ENVIRONMENT
    pv=PACKAGE_VARIANT
    ik=INSTALL_KERNEL
    kf=KERNEL_FLAVOUR
    kp=KERNEL_PROVIDER
    ks=KERNEL_SERIES
    kc=KERNEL_CAPABILITIES
    kbd=KERNEL_BUILD_DKMS
    ib=INITRAMFS_BUILDER
    lo=LOCALE
    ml=MULTILINGUAL
    kl=KEEP_LOCALES

Scalar filters use exact string equality. Inside the **01-kernel** build flow, **KERNEL_CAPABILITIES** is an indexed Bash array, so **kc** matches any detected capability. The **ks** and **kc** values are not available to ordinary later modules.

# CONFIGURATION VALUES

The default **build.conf** currently lists:

**DISTRIBUTION**
:   Debian **buster**, **bullseye**, **bookworm**, **trixie**; Ubuntu **bionic**, **focal**, **jammy**, **noble**, **resolute**; or Devuan **beowulf**, **chimaera**, **daedalus**, **excalibur**.

**DISTRIBUTION_ARCH**
:   **amd64**, **i386**, or **i386-pae**.

**DESKTOP_ENVIRONMENT**
:   **core**, **flux**, **xfce**, or **lxqt**.

**PACKAGE_VARIANT**
:   **minimum**, **standard**, **toolbox**, or **ultra**. The builder normalizes Flux to **minimum**.

**INSTALL_KERNEL**
:   Whether to install a kernel.

**KERNEL_PROVIDER**
:   **distribution** or **minios**.

**MINIOS_KERNEL_SERIES**
:   User selection for the MiniOS provider: **auto**, **6.1**, or **6.12**.

**KERNEL_FLAVOUR**
:   **none**, **rt**, or **cloud**.

**KERNEL_BUILD_DKMS**
:   Whether to build additional DKMS drivers.

**INITRAMFS_BUILDER**
:   **livekit** or **dracut**.

**LOCALE**, **MULTILINGUAL**, **KEEP_LOCALES**
:   Locale selection and locale-retention settings.

CondinAPT can use an unmapped full variable name only when that variable is present in the configuration supplied with **-c**. The generated module configuration includes selected distribution, compression, kernel, locale, timezone, user, and builder values. It does not include every **build.conf** value; boot-loader, menu, persistence, snapshot, and most cache or debugging settings are unavailable to ordinary module calls unless a module supplies them explicitly.

# DERIVED VALUES

**DISTRIBUTION_PROFILE**
:   Behavior profile derived from the selected suite, normally **debian** or **ubuntu**. Devuan suites use the Debian profile.

**INIT_SYSTEM**
:   Derived init-system profile, normally **systemd** or **sysvinit**.

**KERNEL_SERIES** and **KERNEL_CAPABILITIES**
:   Resolved kernel values appended to a temporary configuration used only by CondinAPT calls inside the **01-kernel** build flow. **MINIOS_KERNEL_SERIES** is the user setting; **KERNEL_SERIES** is the detected series used by **ks**. Neither **ks** nor **kc** is propagated to ordinary later modules.

# PACKAGE LIST EXAMPLES

Install additional codecs except in the minimum variant:

    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-bad -pv=minimum
    gstreamer1.0-libav -pv=minimum

Select applications by variant and desktop:

    audacity +{pv=toolbox|pv=ultra}
    kdenlive +{pv=toolbox|pv=ultra} +{de=xfce|de=lxqt}

Select a target release:

    ffmpeg @bookworm-backports +d=bookworm

Inside **linux-live/scripts/01-kernel/packages.list**, exclude DKMS packages when the selected kernel already has the capability:

    ntfs3-dkms -kc=ntfs3
    aufs-dkms -kc=aufs +kbd=true

Choose a package during planning, not after an APT transaction failure:

    exfatprogs || exfat-utils && exfat-fuse

# REBUILDING MODULES

**build-modules** skips a module whose SquashFS artifact is already present. After changing a module, remove its existing artifact from the selected work directory's **image/** tree and rerun **minios-live build-modules**. The builder invalidates the following non-kernel module chain once an artifact is missing. Kernel module rebuilding follows separate handling in the builder.

# FILES

**linux-live/condinapt**
:   CondinAPT implementation in a source checkout.

**linux-live/condinapt.map**
:   MiniOS filter mapping in a source checkout.

**linux-live/build.conf**
:   Default source-tree build configuration.

**linux-live/scripts/**
:   Reusable module sources.

**linux-live/environments/**
:   Ordered module selections for each desktop environment.

**/usr/share/minios-live/**
:   Installed build scripts, module sources, environments, CondinAPT, and filter map.

**/etc/minios-live/build.conf**
:   Installed default build configuration.

# SEE ALSO

**condinapt**(1), **minios-live**(1), **minios-cmd**(1)

# AUTHORS

MiniOS Development Team <https://minios.dev>
