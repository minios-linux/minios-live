# Release Notes v5.1.0

This release includes bug fixes for all issues discovered since v5.0.0, along with new features and improvements.

## 1. Build System and Code Quality Optimization
- **Improved Man Page Generation:** The `Makefile` and `debian/rules` have been updated to improve man page generation and localization.
- **Translation Enhancements:** The translation process has been improved, with updated `.po` files and better statistics output.
- **Package Handling:** The package installation logic has been refactored to streamline repository handling, especially for Ubuntu.
- **Code Refactoring:** Several scripts have been refactored for improved clarity, readability, and functionality.

## 2. User Experience (UX) and Interface Improvements
- **Boot Menu:** Multilingual support has been added for the SYSLINUX and GRUB boot menus.
- **Boot Parameters:** Added automatic timezone and keyboard layout configuration based on selected language in boot menu
- **Desktop Keyboard Setup:** Added automatic keyboard layout configuration in desktop environment from system settings. Now supports keyboard model, layout, variant, and options (including layout switching combinations like `grp:ctrl_shift_toggle`, `grp:caps_toggle`). Configuration is processed by live-config component `0150-keyboard-configuration` and applied to XFCE/Fluxbox desktop environments. Desktop keyboard setup utility moved to minios-tools package.
- **Virtual Machine Display:** Added `minios-virtual-resolution` utility for automatic screen resolution adjustment in virtual machines without guest utilities. Supports `virtres=WIDTHxHEIGHT` kernel parameter and `novirtres` to disable. Moved to minios-tools package.
- **Ventoy Compatibility:** Compatibility symlinks for Ventoy have been added to improve the boot experience.

## 3. System and Package Management
- **New Ubuntu Support:** Support for Ubuntu Bionic and Focal has been added to the build configuration.
- **Kernel Management:** The kernel options in `minios-cmd` have been refactored, replacing `kernel-type` with `kernel-flavour`.
- **Package Updates:** Several packages have been added and removed to optimize the different MiniOS editions. Added `firmware-mediatek` package to improve support for MediaTek wireless adapters.
- **Audio System Modernization:** Transitioned from PulseAudio to PipeWire for Standard, Toolbox, and Ultra editions, providing modern audio/video routing and lower latency.

## 4. Applications and Tools Updates

**Session Manager:**
- Major update with new functionality - added session export/import to .tar.zst archives with automatic mode conversion support
- Implemented session copy and conversion between modes (native/dynfilefs/raw)
- Added full FAT32/NTFS filesystem support with fallocate for raw sessions and sync after mkfs.ext4
- Implemented disk space checking for all operations
- Fixed session size handling with proper size preservation and corrected MB/bytes conversions
- Changed default session size from 4000MB to 1000MB
- Fixed GUI SpinButton range and crash issues
- Improved reliability on FAT32 filesystems
- Added MiniOS version/edition detection helpers
- Updated bash completion for new commands
- Added experimental dracut-based initrd support with path corrections

**MiniOS Installer:**
- Added experimental dracut-based initrd support with automatic detection
- Implemented multilingual configuration copying and localized bootloader configs
- Enhanced SYSLINUX configuration processing with localized configs and fallback mechanisms
- Refactored bootloader detection to support multiple types
- Auto-detect boot menu language from cmdline locales parameter
- Set boot menu language combo box to value inherited from cmdline
- Remove live-config parameters from boot configs for localized installations (parameters stored in minios/config.conf instead)
- Enhanced integration with configurator - automatically passes `-i` flag for parameter inheritance
- User settings from current live session are automatically detected and suggested during installation
- Added French and Portuguese (Portugal) translations
- Improved Ventoy compatibility symlink handling
- Updated zero_fill_disk function to 2MB overwrite size
- Added gir1.2-udisks-2.0 dependency

**MiniOS Configurator:**
- Added `-i/--inherit-cmdline` option to automatically inherit configuration settings from kernel command line
- Configurator detects and uses settings from the running live system when launched from installer
- Configuration is pre-filled with current boot parameters for improved installation workflow
- Added support for parsing 21 unique config parameters from kernel command line (42 cmdline parameter variants)

**Kernel Manager:**
- Added automatic detection and support for both dracut and livekit initramfs builders
- Implemented JSON output support
- Enhanced error handling in main function
- Improved encoding detection in Syslinux config updates
- Added multilingual SYSLINUX configuration support
- Updated translations
- Improved Ventoy compatibility

**MiniOS Tools (sb2iso, dir2sb, etc.):**
- Implemented experimental dracut-based initrd support across all tools
- Improved Ventoy compatibility with new cleanup function and method changes
- Enhanced sb2iso script with unified menu type handling and automatic bootloader type detection
- Improved language support and refactored variable names for clarity
- Added bash completion functions for dir2sb, rmsbdir, savechanges, and sb2dir
- Suppressed error output in file searches
- Removed unnecessary source paths
- Updated documentation

**Mini Commander:**
- New application added to repository - simplified clone of Midnight Commander for terminal environments
- Provides dual-pane file manager interface with basic file operations

**Ncurses Menu:**
- New application added to repository - terminal-based menu utility
- Features multi-line title support and improved layout handling

**Rescuezilla:**
- Replaced `nbd-server` and `nbd-client` dependencies with `nbdkit`
- Updated SVG button files for improved interface

**DriveUtility:**
- Enhanced disk filtering logic to hide mounted disks by default for improved safety
- Renamed "Show all disks (DANGEROUS)" checkbox to "Show mounted disks"
- Added confirmation dialog for operations on mounted devices with color-coded buttons and detailed risk warnings
- Fixed mountutils to allow operations on mounted devices when explicitly confirmed by advanced users
- Added support for optical drives (CD/DVD) in Create Image mode for ISO creation
- Updated translations for new UI strings across all supported languages

**Flux Tools:**
- Added Session Manager and Kernel Manager integration to fbliveapp
- Implemented gettext support for translations in fbappselect, fbdesktop, and fbliveapp scripts
- Updated French translations
- Refined VLC descriptions and installation prompts
- Lowered bash dependency to 4.4
- Added manual pages

## 5. System Components and Documentation

**Live Config:**
- Enhanced configuration scripts to detect initramfs type for ISO paths
- Improved user-media configuration to check for from.log in initramfs log directory
- Updated init script to copy config.conf if it exists
- Refactored components to support default Debian Live paths alongside MiniOS paths
- Added support for fluxbox-flux alongside fluxbox-slax

**Elementary MiniOS Icon Theme:**
- Added new icons - media-floppy and package-x-generic at 64px size

**Documentation:**
- Updated with priority queue regex pattern matching support
- Added new boot parameters (including `automount`)
- Comprehensive Rebuilding ISO documentation
- Added curl to required packages list

## 6. Dracut Integration
- **Dracut as a Primary Initramfs Builder:** This release integrates `dracut` as a fully supported alternative `initramfs` builder. While MiniOS continues to use `livekit` by default as the stable and production-ready option, `dracut` can now be selected during system builds by setting the `INITRAMFS_BUILDER` variable in `build.conf`. This provides users with more flexibility and choice in their system configurations.
- **Script and Configuration Updates:** Numerous scripts have been updated to support both `livekit` and `dracut`, including `minios-init`, `minios-shutdown`, and various build scripts. The system automatically detects which initramfs builder was used and adapts accordingly.
