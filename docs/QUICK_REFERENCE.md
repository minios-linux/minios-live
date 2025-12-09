# MiniOS Live Quick Reference

Quick reference for common tasks and commands in MiniOS Live development.

## Table of Contents
- [Building ISO Images](#building-iso-images)
- [Testing and Validation](#testing-and-validation)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

## Building ISO Images

### Basic Build
```bash
# Build with default settings (Standard edition)
sudo ./minios-live -

# Build specific edition
sudo ./minios-cmd -d trixie -a amd64 -de xfce -pv standard
```

### Build Commands
```bash
# Full build from scratch
sudo ./minios-live -

# Build specific phases
sudo ./minios-live build-bootstrap        # Create base system only
sudo ./minios-live build-bootstrap - build-chroot  # Base + packages
sudo ./minios-live build-iso              # Create ISO from existing build

# Build range
sudo ./minios-live build-live - build-iso # Live system through ISO
```

### Build Options (minios-cmd)
```bash
# Distribution options
-d, --distribution      # bookworm, bullseye, trixie, jammy, noble
-a, --architecture      # amd64, i386, i386-pae, arm64
-de, --desktop          # xfce, lxqt, flux, core
-pv, --variant          # standard, toolbox, ultra, minimum

# Kernel options
-kf, --kernel-flavour   # none, rt, cloud
-aufs                   # Enable AUFS support
-dkms                   # Build DKMS modules

# Locale options
-l, --locale           # en_US, ru_RU, de_DE, es_ES, etc.
-ml, --multilingual    # Enable all locales
-kl, --keep-locales    # Keep all locales
-tz, --timezone        # Timezone (e.g., Etc/UTC, Europe/Moscow)

# Boot options
-ib, --initramfs       # livekit (default) or dracut
-mln, --menu-language  # multilang, ru_RU, en_US, etc.
```

### Example Builds
```bash
# Standard English build
sudo ./minios-cmd -d trixie -a amd64 -de xfce -pv standard

# Russian localized build
sudo ./minios-cmd -d trixie -a amd64 -de xfce -pv standard -l ru_RU -mln ru_RU

# Toolbox edition with AUFS
sudo ./minios-cmd -d trixie -a amd64 -de xfce -pv toolbox -aufs -dkms

# Multilingual build
sudo ./minios-cmd -d trixie -a amd64 -de xfce -pv standard -ml -kl

# Ubuntu build
sudo ./minios-cmd -d jammy -a amd64 -de xfce -pv standard

# Flux (minimal) build
sudo ./minios-cmd -d trixie -a amd64 -de flux -pv minimum
```

## Testing and Validation

### Code Quality Checks
```bash
# Run ShellCheck on main scripts
shellcheck minios-live minios-cmd

# Run ShellCheck on all scripts
find . -name "*.sh" -type f -exec shellcheck {} \;

# Check bash syntax
bash -n minios-live
bash -n minios-cmd
```

### Run Tests
```bash
# CondinAPT tests
cd linux-live
./test_condinapt.sh ./condinapt

# Syntax check all scripts
find . -name "*.sh" -type f ! -path "./build/*" -exec bash -n {} \;
```

### ISO Testing
```bash
# Test in QEMU (BIOS)
qemu-system-x86_64 -m 2048 -cdrom build/minios-*.iso

# Test in QEMU (UEFI)
qemu-system-x86_64 -m 2048 -bios /usr/share/ovmf/OVMF.fd -cdrom build/minios-*.iso

# Test with KVM acceleration
qemu-system-x86_64 -m 2048 -enable-kvm -cdrom build/minios-*.iso
```

## Common Tasks

### Configuration
```bash
# Edit build configuration
nano linux-live/build.conf

# Generate config from command line
./minios-cmd --config-only -d trixie -a amd64 -de xfce -pv standard
```

### Managing Modules
```bash
# List all modules
ls -l linux-live/scripts/

# Add new module
mkdir linux-live/scripts/15-mymodule
nano linux-live/scripts/15-mymodule/install
nano linux-live/scripts/15-mymodule/packages.list

# Disable module
touch linux-live/scripts/XX-module/skip_conditions.conf
```

### Cleaning Build Artifacts
```bash
# Clean build directory
sudo rm -rf build/

# Clean specific distribution build
sudo rm -rf build/trixie-*

# Unmount any stuck mounts
sudo ./tools/unmount-dirs.sh build/trixie-*/
```

### Package Management
```bash
# Test package filtering (condinapt)
cd linux-live
./condinapt -c build.conf -l packages.list -s

# Check package availability
apt-cache policy package-name

# Search for packages
apt-cache search keyword
```

## Directory Structure Quick Reference

```
Build Output:
  build/
  ├── trixie-standard-amd64/    # Work directory
  │   ├── core/                 # Chroot environment
  │   └── iso/                  # ISO staging area
  ├── iso/                      # Final ISO output
  └── aptcache/                 # APT cache

Source Structure:
  linux-live/
  ├── scripts/                  # Module scripts
  │   ├── 00-core/             # Core system
  │   ├── 01-kernel/           # Kernel
  │   ├── 03-gui-base/         # GUI base
  │   ├── 04-*-desktop/        # Desktops
  │   └── 05-*-apps/           # Applications
  ├── bootfiles/               # Boot configuration
  └── initramfs/               # Initramfs builders
```

## Troubleshooting

### Common Issues

#### Build Fails at Package Installation
```bash
# Check internet connection
ping -c 3 deb.debian.org

# Clear APT cache
sudo rm -rf build/aptcache/

# Check repository availability
apt-cache policy
```

#### Chroot Issues
```bash
# Unmount stuck mounts
sudo ./tools/unmount-dirs.sh build/trixie-*/

# Check what's mounted
mount | grep build

# Force unmount
sudo umount -l build/trixie-*/core/proc
```

#### ISO Boot Issues
```bash
# Verify ISO integrity
md5sum build/minios-*.iso

# Check ISO structure
isoinfo -l -i build/minios-*.iso

# Test boot files
xorriso -indev build/minios-*.iso -find
```

#### Permission Issues
```bash
# Ensure running as root
sudo -i

# Fix ownership issues
sudo chown -R root:root build/trixie-*/core/

# Check permissions
ls -la build/
```

### Debug Options

```bash
# Enable verbose output (edit build.conf)
VERBOSITY_LEVEL=2

# Enable bash debugging
VERBOSITY_LEVEL=3  # Shows all commands

# Export logs (edit build.conf)
EXPORT_LOGS="true"  # Saves logs to minios/logs/
```

### Getting Help

```bash
# View help
./minios-live --help
./minios-cmd --help

# Check version
head -1 debian/changelog

# View man pages (if installed)
man minios-live
man minios-cmd
man condinapt
```

## Environment Variables

```bash
# Build directory
BUILD_DIR="/path/to/build"

# Use existing config
BUILD_CONF="/path/to/build.conf"

# Build scripts location (for development)
BUILD_SCRIPTS="/path/to/linux-live"
```

## Performance Tips

### Speed Up Builds
```bash
# Use apt-cacher-ng
sudo apt-get install apt-cacher-ng
# Edit build.conf: USE_APT_CACHE="true"

# Use local mirror
# Edit build.conf: DEBIAN_MIRROR="http://local-mirror/"

# Reduce compression (faster, larger)
# Edit build.conf: COMP_TYPE="lz4"

# Skip unnecessary phases
sudo ./minios-live build-modules - build-iso
```

### Reduce ISO Size
```bash
# Maximum compression
# Edit build.conf: COMP_TYPE="xz"

# Remove unused locales
# Edit build.conf: KEEP_LOCALES="false"

# Minimal package variant
sudo ./minios-cmd -pv minimum

# Remove GRUB modules
# Edit build.conf: GRUB_REMOVE_UNUSED_MODULES="true"
```

## Development Workflow

```bash
# 1. Clone repository
git clone https://github.com/minios-linux/minios-live.git
cd minios-live

# 2. Make changes
nano linux-live/scripts/XX-module/install

# 3. Test changes
./minios-cmd --config-only -d trixie -a amd64 -de xfce -pv standard
sudo ./minios-live -

# 4. Validate
shellcheck minios-live minios-cmd
cd linux-live && ./test_condinapt.sh ./condinapt

# 5. Commit
git add .
git commit -m "feat: add new feature"
git push origin feature-branch
```

## Quick Tips

- Always run build commands as root
- Use `-c` flag for custom build.conf location
- Check available disk space before building (20GB+ recommended)
- ISO files are created in `build/iso/` directory
- Use `toram` boot parameter to copy system to RAM
- Press Tab in boot menu to edit boot parameters
- Use `debug` boot parameter for troubleshooting

## Additional Resources

- [Full Documentation](https://github.com/minios-linux/minios-live/wiki)
- [Architecture Guide](docs/ARCHITECTURE.md)
- [Contributing Guide](CONTRIBUTING.md)
- [Security Guide](docs/SECURITY.md)
- [Official Website](https://minios.dev)
