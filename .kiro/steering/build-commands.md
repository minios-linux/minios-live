# Build Commands Reference

## minios-live Usage

### Syntax
```bash
./minios-live [start_cmd] [-] [end_cmd]
```

### Available Commands
- `build-bootstrap` - Install minimal base via debootstrap
- `build-chroot` - Install packages in chroot
- `build-live` - Create core SquashFS
- `build-modules` - Build additional modules
- `build-boot` - Generate initrd and boot files
- `build-config` - Generate configuration
- `build-iso` - Create final ISO
- `remove-sources` - Cleanup

### Examples
```bash
# Full build
./minios-live -

# Single step
./minios-live build-iso

# Range: start to specific step
./minios-live - build-chroot

# Range: specific step to end
./minios-live build-bootstrap -

# Range: between steps
./minios-live build-bootstrap - build-chroot
```

## minios-cmd Usage

### Required Options
```bash
minios-cmd -d <distribution> -a <architecture> -de <desktop> -pv <variant>
```

### Common Options
| Option | Description | Values |
|--------|-------------|--------|
| `-d, --distribution` | Distribution | bookworm, trixie, jammy, noble |
| `-a, --architecture` | Architecture | amd64, i386 |
| `-de, --desktop-environment` | Desktop | xfce, flux, lxqt |
| `-pv, --package-variant` | Variant | minimum, standard, toolbox, ultra |
| `-c, --compression-type` | Compression | zstd, xz, lz4 |
| `-l, --locale` | Locale | en_US, ru_RU, de_DE, etc. |
| `-ib, --initramfs-builder` | Initramfs | livekit, dracut |
| `-aufs` | Enable AUFS kernel | flag |
| `-dkms` | Build DKMS modules | flag |
| `-kl, --keep-locales` | Keep all locales | flag |
| `-ml, --multilingual` | Multilingual support | flag |
| `--config-only` | Generate config only | flag |

### Build Examples
```bash
# Standard Debian Bookworm
minios-cmd -d bookworm -a amd64 -de xfce -pv standard

# Toolbox with AUFS and DKMS
minios-cmd -d bookworm -a amd64 -de xfce -pv toolbox -aufs -dkms -kl

# Ubuntu with Russian locale
minios-cmd -d jammy -a amd64 -de xfce -pv standard -l ru_RU

# Generate config only
minios-cmd --config-only --config-file myconfig.conf \
           -d trixie -a amd64 -de xfce -pv standard
```

## CondinAPT Usage

### Syntax
```bash
condinapt -l <packages.list> -c <config> [-m <mapping>] [options]
```

### Options
| Option | Description |
|--------|-------------|
| `-l, --package-list` | Package list file (required) |
| `-c, --config` | Configuration file (required) |
| `-m, --filter-mapping` | Filter mapping file |
| `-s, --simulation` | Dry run, no installation |
| `-C, --check-only` | Check if packages installed |
| `-v, --verbose` | Verbose output |
| `-vv, --very-verbose` | Very verbose output |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BUILD_DIR` | Build output directory | `./build` |
| `BUILD_CONF` | Configuration file path | `linux-live/build.conf` |
| `VERBOSITY_LEVEL` | Output verbosity (0-2) | 1 |
