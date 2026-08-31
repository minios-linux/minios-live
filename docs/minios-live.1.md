% MINIOS-LIVE(1) MiniOS Live System Builder
% MiniOS Development Team
% September 2026

# NAME

minios-live - build MiniOS ISO images in ordered stages

# SYNOPSIS

**minios-live** [**-h** | **\-\-help**] [*start-command*] [**-**] [*end-command*]

# DESCRIPTION

**minios-live** builds a MiniOS live system as an ordered sequence of stages. It creates a base system, layered SquashFS modules, boot files, configuration data, and the final ISO.

The default **build.conf** currently lists Debian **buster**, **bullseye**, **bookworm**, and **trixie**; Ubuntu **bionic**, **focal**, **jammy**, **noble**, and **resolute**; and Devuan **beowulf**, **chimaera**, **daedalus**, and **excalibur**. It lists **amd64**, **i386**, and **i386-pae** architectures; **core**, **flux**, **xfce**, and **lxqt** environments; **minimum**, **standard**, **toolbox**, and **ultra** variants; and **xz**, **lzo**, **gz**, **lz4**, and **zstd** compression.

Not every combination is necessarily available. The installed configuration, selected environment, and configured repositories determine what can be built.

# REQUIREMENTS

Build stages require root. Help does not.

A source-tree build requires a Debian or Ubuntu host and the packages listed in **linux-live/prerequisites.list**. Repository access must be available directly or through the configured cache. The default configuration enables apt-cacher-ng at **127.0.0.1:3142**; run that service or set **USE_APT_CACHER=false**.

Do not run internal scripts from the **linux-live** directory directly.

The current bootstrap uses **debootstrap --no-check-gpg** and retrieves some repository keys over unauthenticated HTTP. Independently verify build inputs before treating a locally built image as a trusted release artifact.

# COMMANDS

Commands run in the following order. Hyphens and underscores are interchangeable in command names.

**build-bootstrap**
:   Recreate the selected target's **core** and **image** trees, then create or restore the minimal root filesystem.

**build-chroot**
:   Install and configure core system components in the chroot.

**build-live**
:   Create the core SquashFS image.

**build-modules**
:   Build additional SquashFS modules.

**build-boot**
:   Generate boot files, initrd, and boot-loader configuration.

**build-config**
:   Generate live-system configuration data.

**build-iso**
:   Create the final ISO from prepared build data.

**remove-sources**
:   If **REMOVE_SOURCES=true**, delete and recreate the complete selected work directory. Otherwise this stage does nothing.

# RANGE SELECTION

No arguments, **-h**, or **\-\-help** display help.

A single command runs only that stage. **start-command - end-command** runs an inclusive range. **- end-command** starts at the first stage. **start-command -** continues through the final stage. A lone **-** runs every stage.

# EXAMPLES

Run the complete build:

    sudo minios-live -

Run from the first stage through chroot installation:

    sudo minios-live - build-chroot

Rebuild boot and configuration data:

    sudo minios-live build-boot - build-config

Create an ISO from prepared data:

    sudo minios-live build-iso

# CONFIGURATION

A source checkout reads **linux-live/build.conf** by default and uses **build/** below the checkout. An installed copy reads **/etc/minios-live/build.conf** and uses **build/** below the current directory. Set **BUILD_CONF** and **BUILD_DIR** to override those defaults.

Configuration files are sourced as Bash and must be trusted.

Additional software is selected in module **packages.list** files. Modules are linked into the selected environment under **linux-live/environments/**.

**build-modules** skips modules whose SquashFS artifacts already exist. After changing a module, remove its artifact from the selected work directory's **image/** tree before rebuilding. The builder then invalidates the following module chain; kernel module rebuilding is handled separately.

# FILES

**linux-live/build.conf**
:   Default configuration in a source checkout.

**/etc/minios-live/build.conf**
:   Default configuration for an installed copy.

**linux-live/prerequisites.list**
:   Host packages required for a source-tree build.

# SEE ALSO

**minios-cmd**(1), **condinapt**(1), **condinapt-minios**(7)

# AUTHORS

MiniOS Development Team <https://minios.dev>
