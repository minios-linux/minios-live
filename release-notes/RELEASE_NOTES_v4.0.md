# Release Notes v4.0

## Visual Changes
- **GRUB Splash Screen:** Updated the bootloader splash screen with a new design.
- **Desktop Wallpapers:** Refreshed desktop wallpapers, with an added YouTube video splash screen as wallpaper.
- **Icon Theme Updates:**
  - The icon theme has been renamed to `elementary-minios` and updated to version 0.19.
  - Added new icons to ensure a uniform appearance in menus and actions, including operations for sb modules.
  - Added icons for sb module actions in Thunar's context menu, available in multiple locales (en, ru, es, pt_BR, it, fr, de).
  - Fixed icon rendering issues in older distributions.
- **XFCE Bottom Panel Modifications:**
  - Increased panel height to **48 pixels**.
  - Adjusted application icon sizes to **32 pixels**.
  - Removed application name labels for running apps.
  - Added date display alongside the clock.
  - Standardized tray icon size to **16 pixels** for a consistent look.
- **File Manager Enhancements:**
  - Introduced context menu options in Thunar for sb module management, including actions like packing, extracting, mounting, and unmounting modules.

## General Changes
- **Unified Build Configuration:**
  - All MiniOS editions are now built using two new configuration files: general.conf and build.conf.
- **Build Script Optimization:**
  - Removed rarely used options, simplifying the build process.
- **Deprecated Distribution Support:**
  - Support for outdated distributions Kali Linux and Astra Linux has been discontinued.
- **Script and Library Overhaul:**
  - Removed utilities `minios-modules` and `minios-configure`.
  - Overhauled the `minioslib` library to eliminate variable-related errors and improve some functions.
  - Revised the `minios-startup` script to fix variable-related errors.
- **System Directory Script Support:**
  - Support for running build scripts from system directories in Linux.
- **Editions:**
  - New Edition - **Toolbox** is a system administrator's multitool with a large set of utilities for PC maintenance and data recovery.
  - Removed editions: **Flux**, **Minimum**, **Maximum**, **Ultra**, and **Puzzle**.
- **Improved Boot and Tool Scripts:**
  - Separated MiniOS boot scripts into the new `minios-boot` package.
  - Transferred package management scripts into the `minios-tools` package.
  - Created a standalone library `libminioslive` for shared MiniOS utility functions.
  - The browser splash screen that is launched at first startup is allocated to the `minios-welcome` package.
- **Other:**
  - Added option to mount user folders to storage for FAT32, NTFS, and exFAT.

## Utility Changes
- **Utility Removal and Reorganization:**
  - Removed utilities: `upg2sb`, `minios-bundle`, and `pxe`.
  - Renamed `scr2sb` to `script2sb` and `minios-geniso` to `sb2iso` for clarity.
  - Integrated `upg2sb` functionality into `apt2sb`.
  - Merged `minios-bundle` functionality into `sb` utility.
  - Renamed `gtkdialog` used in Flux to `gtkask` to avoid conflicts.
- **New Utilities:**
  - Introduced `minios-configurator` for configuring the `minios.conf` configuration file.
  - Added `chroot2sb` utility for creating modules via manual command input.
  - Added `minios-kernelpack` for replacing the standard MiniOS kernel with available kernels from MiniOS and Debian repositories.
  - Added `minios-live` to the repository to build MiniOS images.
  - Added `eddy` to the repository to install local deb packages.
  - Added `eddy-handler` to the repository to update the package database before running Eddy if the database is out of date.
- **Enhanced MiniOS Installer:**
  - Rewritten for improved reliability and user experience.
  - Added a console interface for installations from tty.
  - Supported installation on mmcblk and exFAT.
  - Added a launch of MiniOS Configurator for basic system setup post-installation.

## Edition Changes
- **Standard:**
  - Removed the Remmina packages.
  - Added `xdg-user-dirs-gtk` for user directories in the Places menu.
  - Added xrdp server.
- **Toolbox:**
  - SSH enabled by default.
  - Added a range of utilities: `gtkhash`, `czkawka`, `zulucrypt-gui`, `keepassxc`, `guymager`, `isomaster`, `unetbootin`, `qphotorec`, `zenmap`, `veracrypt`, `wxhexeditor`, `uget`, `inxi`, `bonnie++`, `iperf3`, and more.
  - Included `lshw-gtk`, `HDSentinel-GUI`, and `MintStick`.
- **Flux:**
  - Fixed file associations and added translations for `.desktop` files.
  - Included scripts for automatic menu and `.desktop` file generation based on locale.
  - Added support for building Flux images on Ubuntu 22.04 and 24.04.

## System Improvements
- **Kernel Update:** The main MiniOS kernel has been updated to version 6.1.119.
- **Driver Support:** Added precompiled drivers (`rtl8188eus`, `rtl8723cs`, `rtl8812au`, and others) for the standard MiniOS kernel on amd64.
- **Storage Rights:** Enabled full user rights on FAT32, NTFS, and exFAT file systems, removing the need for root permissions.
- **Virtual Machine Enhancements:** Added automatic resolution changes in VMware, VirtualBox, KVM, and QEMU to 1280x800.
