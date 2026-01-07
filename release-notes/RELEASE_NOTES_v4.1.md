# Release Notes v4.1

## Interface Changes
- Updated the appearance of the Ultra edition to match the MiniOS 4 style.
- Updated the LXQT appearance to match the MiniOS 4 style.
- Added wallpapers for the Ultra, Minimum, and Home editions.
- Added icons for PDFShuffler and QDiskInfo to the `elementary-minios` theme; the HDSentinel icon has been removed.
- If the system does not support aufs, menu items for mounting and unmounting modules will be hidden.

## Functional Changes
- Fixed the autologin bug in the Flux edition.
- Implemented support for storing data in raw images (similar to Ubuntu casper-rw).
- Added automatic detection of the size required for storing data in raw and dynfilefs images.
- Implemented full Ventoy support, both when storing data in images on the Ventoy partition and when using a separate partition for storing changes.
- Changed the principle of creating images for storing changes on POSIX-incompatible file systems: the size of the space in the image is now equal to the free space on the disk.
- `bootinst.sh` now requires root privileges to run.
- Added the ability to work with persistent storage when writing an ISO image using dd, balenaEtcher, and similar utilities.  A partition for persistent changes is automatically created on the first boot.
- Added the ability to build with the C locale.
- Changed the init loading logic: copying the system to RAM now occurs before activating persistent changes.
- Added new kernel parameters that regulate copying the system to RAM (`toram`, `toram=trim`, `toram=full`).
- Changed the logic of running scripts at boot: startup no longer depends on the `SCRIPTS` variable in `minios.conf`.
- Improved the structure of the ISO image; added support for booting from EFI 32-bit.
- Adapted the `sb2iso` code for the new ISO format.
- Migrated ntfs3 and polkit management from init to systemd.
- Data cleanup during MiniOS build is moved to the `build_bootstrap` stage.
- The default initrd compression algorithm now depends on the system compression algorithm.
- Removed the `-zstd` suffix from image and module names.

## Utility Changes
- Added the utilities `mke2fs`, `e2fsck`, `lsblk`, `parted`, `partprobe` to the initrd.
- QDiskInfo rewritten in QT5 and added to the repository.

## Edition Changes
- **Standard:**
  - Added the MintStick utility for writing disk images and formatting flash drives.
  - Made changes to MintStick management for compatibility with Debian Trixie and Sid.
- **Toolbox:**
  - Added `telnet`, `QEMU`, `QEMU Utils`, `Virtual Machine Manager`, `memtest`, and `VSCodium`.
  - Replaced HDSentinel with QDiskInfo.
  - The default kernel is the standard Debian 12 kernel with no module hot-plugging support, but with Secure Boot support.
- **Ultra:**
  - Updated package lists, included all packages from Toolbox.
  - Removed `telegram-desktop`, `gsmartcontrol`, and `ttf-mscorefonts-installer`.
  - Returned to the list of available editions.
  - The default kernel is the standard Debian 12 kernel with no module hot-plugging support, but with Secure Boot support.
- **Minimum:** Reduced size by removing some packages.

## Module Changes
- Removed the `xfce-apps` module; its functions are now performed by `xfce-desktop`.
- Graphical programs not included in the DE are moved to the `apps` module.
- The `xorg` module has been replaced by `gui-base`, which contains the base libraries GTK2, GTK3, QT5, icon themes, and other components necessary for all DEs.

## System Changes
- Added `virtres` and `novirtres` to the kernel parameters.
- Added the `ntfs3-dkms` package to the repository for NTFS3 driver support in Debian kernels.
- Added quirks from the new version of libinput to support new input devices.
- Added `dnsmasq-base` to all editions.
- MiniOS kernel with AUFS support has been updated to 6.1.124.
- The pre-compiled wireless adapter modules have been replaced with DKMS modules.
