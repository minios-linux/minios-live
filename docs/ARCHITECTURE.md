# MiniOS Live Architecture Overview

This document provides an architectural overview of the MiniOS Live build system.

## System Components

### Core Scripts

#### minios-live
The main build orchestrator that:
- Manages the complete build pipeline
- Coordinates between different build phases
- Handles command-line argument processing
- Provides progress tracking and logging

**Key Functions:**
- `build_bootstrap`: Creates the base Debian/Ubuntu system
- `build_chroot`: Installs packages and configures the system
- `build_live`: Prepares the live system components
- `build_modules`: Creates modular system components
- `build_boot`: Configures bootloaders (GRUB/SYSLINUX)
- `build_config`: Generates system configuration files
- `build_iso`: Creates the final ISO image

#### minios-cmd
A user-friendly command-line interface that:
- Provides a simplified parameter-based interface
- Generates build.conf from command-line arguments
- Validates user input
- Calls minios-live with appropriate settings

#### minioslib
The core library providing:
- Common utility functions
- Package management operations
- File system operations
- Configuration parsing
- Internationalization support

### Directory Structure

```
minios-live/
├── minios-live              # Main build script
├── minios-cmd               # CLI wrapper
├── linux-live/              # Build system components
│   ├── minioslib            # Core library functions (3800+ lines)
│   ├── build.conf           # Build configuration
│   ├── condinapt            # Conditional package installer
│   ├── scripts/             # Module installation scripts
│   │   ├── 00-core/         # Essential system components
│   │   ├── 01-kernel/       # Kernel packages
│   │   ├── 02-firmware/     # Hardware firmware
│   │   ├── 03-gui-base/     # GUI foundations
│   │   ├── 04-*-desktop/    # Desktop environments
│   │   ├── 05-*-apps/       # Applications
│   │   └── 10-*/            # Optional modules
│   ├── bootfiles/           # Boot configuration
│   │   ├── boot/grub/       # GRUB bootloader files
│   │   └── boot/syslinux/   # SYSLINUX bootloader files
│   └── initramfs/           # Initial RAM filesystem
│       ├── livekit-mos/     # LiveKit-based initramfs
│       └── dracut-mos/      # Dracut-based initramfs
├── debian/                  # Debian packaging files
├── docs/                    # Documentation
├── po/                      # Translations
└── tools/                   # Helper utilities
```

## Build Process Flow

```
1. Configuration
   ├─ Parse command-line arguments (minios-cmd)
   ├─ Load build.conf
   └─ Initialize environment variables

2. Bootstrap Phase (build_bootstrap)
   ├─ Create base directory structure
   ├─ Run debootstrap to create minimal Debian/Ubuntu
   └─ Configure APT repositories

3. Chroot Phase (build_chroot)
   ├─ Enter chroot environment
   ├─ Install kernel packages
   ├─ Install system packages via condinapt
   ├─ Configure locales and timezone
   └─ Apply system configurations

4. Live System Phase (build_live)
   ├─ Copy rootcopy files
   ├─ Configure live boot settings
   └─ Prepare persistence layer

5. Module Phase (build_modules)
   ├─ Create squashfs modules
   ├─ Compress system components
   └─ Organize module hierarchy

6. Boot Phase (build_boot)
   ├─ Configure bootloader (GRUB/SYSLINUX)
   ├─ Generate initramfs (livekit/dracut)
   ├─ Copy kernel and initrd
   └─ Setup multilingual boot menus

7. Configuration Phase (build_config)
   ├─ Generate live system config
   ├─ Setup default users
   └─ Configure system services

8. ISO Creation Phase (build_iso)
   ├─ Organize ISO file structure
   ├─ Create bootable ISO image
   └─ Generate checksums
```

## Key Technologies

### Package Management
- **condinapt**: Custom conditional package installer
  - Supports complex filter expressions
  - Handles package alternatives (||)
  - Conditional installation based on edition/architecture
  - Priority queue for installation order

### Initramfs Builders
- **LiveKit**: Lightweight, custom initramfs (default)
  - Smaller size (~30-40MB)
  - Fast boot times
  - Full MiniOS feature support
  
- **Dracut**: Standard Debian dracut-based initramfs (experimental)
  - Better hardware compatibility
  - Standard Debian tooling
  - Larger size (~50-70MB)

### Bootloaders
- **GRUB**: Primary bootloader for UEFI and BIOS
  - Multilingual support
  - Theme customization
  - Advanced boot options

- **SYSLINUX**: Alternative BIOS bootloader
  - Lighter weight
  - Legacy hardware support
  - Vesamenu interface

### Compression
Supported compression types:
- **zstd**: Default, best balance (fast, good compression)
- **xz**: High compression, slower
- **lzo**: Fast compression, larger size
- **lz4**: Very fast, moderate compression
- **gz**: Compatible, moderate compression

## Configuration System

### build.conf
Main configuration file with sections:
- Distribution settings (name, architecture, desktop)
- Kernel configuration (flavour, AUFS support, DKMS)
- Locale and timezone settings
- Boot loader configuration
- Build options (caching, verbosity, etc.)

### Module Configuration
Each module in `linux-live/scripts/` can have:
- `install`: Main installation script
- `packages.list`: Packages to install (processed by condinapt)
- `rootcopy-install/`: Files to copy to the system
- `rootcopy-postinstall/`: Files to copy after installation
- `skip_conditions.conf`: Conditions to skip module

## Extension Points

### Adding a New Module
1. Create directory: `linux-live/scripts/XX-modulename/`
2. Add `install` script with installation logic
3. Create `packages.list` with package requirements
4. Add any necessary rootcopy files
5. Build system automatically includes the module

### Supporting a New Distribution
1. Add distribution name to `minioslib` common_variables
2. Update distribution URL mappings
3. Add distribution-specific package mappings in condinapt
4. Test package availability and compatibility

### Custom Boot Menus
1. Create theme in `linux-live/bootfiles/boot/grub/*/`
2. Add locale-specific configurations
3. Update `build_boot` function if needed

## Performance Considerations

### Build Optimization
- **APT Cache**: Use apt-cacher-ng to speed up package downloads
- **Parallel Builds**: Some phases can run in parallel
- **Compression Level**: Balance between size and build time
- **Module Caching**: Reuse unchanged modules

### Runtime Optimization
- **Module Loading**: On-demand module loading
- **Copy to RAM**: Optional full system copy for performance
- **Persistence Layer**: Efficient change tracking

## Security Considerations

### Build-Time Security
- Package signature verification
- Secure repository configuration
- Minimal privilege escalation
- Clean chroot environment

### Runtime Security
- Optional SecureBoot support (Debian kernel)
- User permission management
- Service hardening
- Firewall configuration

## Internationalization

### Supported Languages
- English (en_US) - Default
- Russian (ru_RU)
- Spanish (es_ES)
- Portuguese Brazil (pt_BR)
- Portuguese Portugal (pt_PT)
- German (de_DE)
- French (fr_FR)
- Italian (it_IT)
- Indonesian (id_ID)

### Translation System
- GNU gettext for script translations
- PO files in `po/` directory
- Boot menu translations
- System-wide locale support

## Testing Strategy

### Current Tests
- **CondinAPT Test Suite**: Comprehensive package filter testing
- **Syntax Checks**: Bash syntax validation
- **ShellCheck**: Static analysis of shell scripts

### Recommended Additional Tests
- Integration tests for build process
- Module installation tests
- Boot process validation
- Locale/internationalization tests

## Future Improvements

### Short-Term
- Enhanced input validation
- Better error messages
- Improved logging
- Function documentation

### Long-Term
- Plugin system for custom modules
- Web-based configuration UI
- Build result caching
- Distributed build support

## References

- [MiniOS Website](https://minios.dev)
- [GitHub Repository](https://github.com/minios-linux/minios-live)
- [Wiki Documentation](https://github.com/minios-linux/minios-live/wiki)
- [Contributing Guide](../CONTRIBUTING.md)
