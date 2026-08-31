# Building MiniOS with `minios-live`

`minios-live` builds a MiniOS ISO as an ordered sequence of stages. It creates a base system, layered SquashFS modules, boot files, configuration data, and the final ISO.

## Build Targets

The default `linux-live/build.conf` currently exposes these values:

- **Distributions:** Debian `buster`, `bullseye`, `bookworm`, `trixie`; Ubuntu `bionic`, `focal`, `jammy`, `noble`, `resolute`; Devuan `beowulf`, `chimaera`, `daedalus`, `excalibur`
- **Architectures:** `amd64`, `i386`, `i386-pae`
- **Desktop environments:** `core`, `flux`, `xfce`, `lxqt`
- **Package variants:** `minimum`, `standard`, `toolbox`, `ultra`
- **Compression:** `xz`, `lzo`, `gz`, `lz4`, `zstd`

Not every combination is necessarily available. Treat the checked-out `linux-live/build.conf`, environment links under `linux-live/environments/`, and configured package repositories as the source of truth for a particular build.

## Requirements

- Build commands require root. Help can be displayed without root.
- A source-tree build requires a Debian or Ubuntu host and the packages listed in `linux-live/prerequisites.list`.
- Package repositories must be reachable directly or through the configured cache.
- The default configuration enables apt-cacher-ng at `127.0.0.1:3142`. Run that service or set `USE_APT_CACHER="false"`.
- Do not run internal scripts from `linux-live/` directly. Use `./minios-live` or `./minios-cmd`.

The current bootstrap uses `debootstrap --no-check-gpg` and retrieves some repository keys over unauthenticated HTTP. Independently verify build inputs before treating a locally built image as a trusted release artifact.

## Commands

Stages run in this order:

- `build-bootstrap`: recreates the selected target's `core/` and `image/` trees, then creates or restores the minimal root filesystem
- `build-chroot`: installs and configures core system components in the chroot
- `build-live`: creates the core SquashFS image
- `build-modules`: builds additional SquashFS modules
- `build-boot`: generates boot files, initrd, and boot-loader configuration
- `build-config`: generates live-system configuration data
- `build-iso`: creates the final ISO from prepared build data
- `remove-sources`: if `REMOVE_SOURCES=true`, deletes and recreates the complete selected work directory; otherwise it does nothing

Hyphens and underscores are interchangeable in command names, although the hyphenated forms above are preferred.

## Usage

```text
./minios-live [-h | --help] [start_cmd] [-] [end_cmd]
```

- No arguments, `-h`, or `--help` display help.
- One command runs only that stage.
- `start_cmd - end_cmd` runs an inclusive range.
- `- end_cmd` runs from the first stage through `end_cmd`.
- `start_cmd -` runs from `start_cmd` through the final stage.
- `-` runs the complete build.

## Examples

Run the complete build:

```bash
sudo ./minios-live -
```

Run through the chroot stage:

```bash
sudo ./minios-live - build-chroot
```

Rebuild only boot and configuration data:

```bash
sudo ./minios-live build-boot - build-config
```

Create an ISO from already prepared data:

```bash
sudo ./minios-live build-iso
```

## Configuration

A source checkout reads `linux-live/build.conf` by default. An installed copy reads `/etc/minios-live/build.conf`. Override these locations with `BUILD_CONF` and `BUILD_DIR`:

```bash
sudo BUILD_CONF=/absolute/path/build.conf BUILD_DIR=/srv/minios-build ./minios-live -
```

Configuration files are sourced as Bash and must be trusted.

Software for additional modules is selected through each module's `packages.list`. Add a module under `linux-live/scripts/` and link it into the intended directory under `linux-live/environments/`.

`build-modules` skips a module when its SquashFS artifact already exists. After changing a module, remove its existing artifact from `build/<target>/image/<livekit-name>/` before running `build-modules`; the builder then invalidates the following module chain. Kernel module rebuilding is handled separately by the builder.
