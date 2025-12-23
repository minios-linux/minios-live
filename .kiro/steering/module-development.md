# Module Development Guide

## Module Structure

Each module resides in `linux-live/scripts/##-module-name/` with this structure:

```
<MODULE_NAME>/
├── skip_conditions.conf      # (optional) Skip conditions
├── rootcopy-install/         # (optional) Files copied before install
├── install                   # Installation script (runs in chroot)
├── packages.list             # Package list for condinapt
├── patches/                  # (optional) Source patches
├── build                     # (optional) Build script in chroot
├── is_dkms_build             # (optional) DKMS build flag
├── rootcopy-postinstall/     # (optional) Files copied after install
└── postinstall               # (optional) Post-installation script
```

## Module Naming Convention

### Base Modules (01-09)
- Sequentially numbered, gaps auto-restored
- Core system components

### Additional Modules (10+)
- Retain original numbering
- Can use `.package` file for versioned names

## Creating a New Module

### 1. Create Module Directory
```bash
mkdir -p linux-live/scripts/10-mymodule
```

### 2. Create packages.list
Use CondinAPT syntax with filters:
```
# Always install
mypackage

# Conditional installation
optional-pkg +pv=toolbox +pv=ultra
excluded-pkg -pv=minimum

# Version pinning
specific-pkg=1.2.3
```

### 3. Create install Script
```bash
#!/bin/bash
set -e
set -o pipefail
set -u

. /minioslib || exit 1

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Install packages
/condinapt -l "${SCRIPT_DIR}/packages.list" \
           -c "${SCRIPT_DIR}/minios_build.conf" \
           -m "${SCRIPT_DIR}/condinapt.map"

# Additional configuration here
```

### 4. Create skip_conditions.conf (optional)
```
PACKAGE_VARIANT=minimum
DISTRIBUTION_ARCH=i386
```

### 5. Link to Environment
```bash
cd linux-live/environments/xfce
ln -s ../../scripts/10-mymodule
# Or with custom order:
ln -s ../../scripts/10-mymodule 07-mymodule
```

## CondinAPT Filter Syntax

### Filter Prefixes (from condinapt.map)
- `d=` - DISTRIBUTION (bookworm, trixie, etc.)
- `da=` - DISTRIBUTION_ARCH (amd64, i386)
- `dt=` - DISTRIBUTION_TYPE (debian, ubuntu)
- `de=` - DESKTOP_ENVIRONMENT (xfce, flux, lxqt)
- `pv=` - PACKAGE_VARIANT (minimum, standard, toolbox, ultra)
- `kf=` - KERNEL_FLAVOUR (none, rt, cloud)
- `ib=` - INITRAMFS_BUILDER (livekit, dracut)

### Filter Operators
```
+filter=value     # Include if matches
-filter=value     # Exclude if matches
+{a|b}            # Include if ANY matches (OR)
+{a&b}            # Include if ALL match (AND)
-{a|b}            # Exclude if ANY matches
-{a&b}            # Exclude if ALL match
pkg1 || pkg2      # Fallback (try pkg1, else pkg2)
pkg1 && pkg2      # Both required
!package          # Mandatory (fail if unavailable)
pkg@release       # From specific release
```

## Best Practices

1. Always source `/minioslib` for utility functions
2. Use `run_with_spinner` for long operations
3. Create `.package` file for versioned module names
4. Test with `--check-only` flag before full builds
5. Keep rootcopy directories minimal
6. Document skip conditions clearly
