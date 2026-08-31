# Building MiniOS with `minios-cmd`

`minios-cmd` is a command-line frontend for `minios-live`. It copies a configuration template or an existing configuration into a work directory, applies frontend values, and runs the complete `minios-live` build.

## Build Targets

The default `linux-live/build.conf` currently lists:

- **Distributions:** Debian `buster`, `bullseye`, `bookworm`, `trixie`; Ubuntu `bionic`, `focal`, `jammy`, `noble`, `resolute`; Devuan `beowulf`, `chimaera`, `daedalus`, `excalibur`
- **Architectures:** `amd64`, `i386`, `i386-pae`
- **Desktop environments:** `core`, `flux`, `xfce`, `lxqt`
- **Package variants:** `minimum`, `standard`, `toolbox`, `ultra`
- **Compression:** `xz`, `lzo`, `gz`, `lz4`, `zstd`

Not every combination is necessarily available. Check the current configuration template, environment links, and repositories.

## Requirements

All non-help operations, including `--config-only`, currently require root. Source-tree builds also require a Debian or Ubuntu host, the packages in `linux-live/prerequisites.list`, and repository access. The default template enables apt-cacher-ng at `127.0.0.1:3142`; run it or set `USE_APT_CACHER="false"` in the generated configuration.

## Syntax

```text
minios-cmd [OPTIONS]
```

Without `--config-file`, `--distribution`, `--architecture`, `--desktop-environment`, and `--package-variant` are required.

## Options

### Configuration

- `--config-file FILE`: in normal mode, copy `FILE` into the work directory as the base configuration, then write parsed frontend values and non-empty frontend defaults into that copy. With `--config-only`, use `FILE` as the output path and overwrite it.
- `--config-only`: generate a configuration file and do not build. Without `--config-file`, the four required system options are required. Supplying an output path with `--config-file` bypasses that check, and omitted target fields retain template values.
- `-b, --build-dir DIR`: use `DIR` as the build directory.

To use a configuration unchanged by the frontend merge, invoke `minios-live` directly with `BUILD_CONF=/absolute/path/build.conf`.

### System

- `-d, --distribution NAME`: target distribution.
- `-a, --architecture NAME`: target architecture.
- `-de, --desktop-environment NAME`: desktop environment.
- `-pv, --package-variant NAME`: package variant.
- `-c, --compression-type NAME`: SquashFS compression; default `zstd`.

### Kernel

- `-kp, --kernel-provider NAME`: `distribution` or `minios`.
- `-kf, --kernel-flavour NAME`: kernel flavour, such as `none`, `rt`, or `cloud`.
- `-mk, --minios-kernel`: select the MiniOS kernel provider.
- `-mks, --minios-kernel-series NAME`: select `auto`, `6.1`, or `6.12` and use the MiniOS provider.
- `-kpm, --kernel-payload-mode NAME`: `runtime` or `full`.
- `-dkms, --kernel-build-dkms`: build additional DKMS drivers.
- `-aufs, --kernel-aufs`: deprecated alias for `--minios-kernel`.

### Locale And Boot

- `-l, --locale NAME`: system locale; default `en_US`.
- `-ml, --multilingual`: generate all locales declared by `minioslib`.
- `-kl, --keep-locales`: retain all available locales instead of pruning them.
- `-tz, --timezone NAME`: timezone; default `Etc/UTC`.
- `-ib, --initramfs-builder NAME`: `livekit` or `dracut`; default `dracut`.
- `-mln, --menu-language NAME`: `multilang` or a supported menu locale; default `multilang`.

### Ubuntu Pro

- `--ubuntu-pro-token TOKEN`: attach an Ubuntu Pro subscription during a Bionic, Focal, Jammy, or Noble build. Other targets skip attachment with a warning. The builder detaches the subscription and removes the token from the final image. Command-line tokens may be exposed through shell history or process inspection; prefer a protected configuration file where practical.

## Frontend Defaults

- `COMP_TYPE=zstd`
- `KERNEL_PROVIDER=distribution`, except when Trixie-based `i386` or `i386-pae` values are supplied to the frontend through options or the environment; those values select `minios`
- `KERNEL_FLAVOUR=none`
- `MINIOS_KERNEL_SERIES=auto`
- `KERNEL_PAYLOAD_MODE=runtime`
- `KERNEL_BUILD_DKMS=false`
- `LOCALE=en_US`, `MULTILINGUAL=false`, `KEEP_LOCALES=false`
- `LIVE_TIMEZONE=Etc/UTC`
- `INITRAMFS_BUILDER=dracut`, `MENU_LANG=multilang`

These are `minios-cmd` frontend defaults and may differ from values in the full `build.conf` template. Values present only inside `--config-file` are not loaded before defaults are calculated.

## Examples

Build a standard Bookworm Xfce image with frontend defaults:

```bash
sudo ./minios-cmd -d bookworm -a amd64 -de xfce -pv standard
```

Build with a MiniOS kernel, DKMS drivers, and retained locales:

```bash
sudo ./minios-cmd -d bookworm -a amd64 -de xfce -pv toolbox -mk -dkms -kl
```

Build a multilingual image. The current locale table includes German, US English, Spanish, French, Italian, Brazilian Portuguese, and Russian:

```bash
sudo ./minios-cmd -d trixie -a amd64 -de xfce -pv standard -ml
```

Build the Flux minimum variant with the livekit initramfs:

```bash
sudo ./minios-cmd -d bookworm -a amd64 -de flux -pv minimum -ib livekit
```

Generate or overwrite a configuration file:

```bash
sudo ./minios-cmd --config-only --config-file ./myconfig.conf \
  -d bookworm -a amd64 -de xfce -pv standard
```

Use that configuration without frontend merging:

```bash
sudo BUILD_CONF="$PWD/myconfig.conf" ./minios-live -
```
