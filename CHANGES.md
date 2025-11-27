# Changelog
- [Changelog](#changelog)
  - [v2.2.1](#v221)
  - [v2.2.2](#v222)
  - [v2.3](#v23)
  - [v3.0](#v30)
  - [v3.1](#v31)
  - [v3.2](#v32)
  - [v3.3](#v33)
  - [v3.3.1](#v331)
  - [v3.3.2](#v332)
  - [v3.3.3](#v333)
  - [v3.3.4](#v334)
  - [v4.0](#v40)
    - [Visual Changes](#visual-changes)
    - [General Changes](#general-changes)
    - [Utility Changes](#utility-changes)
    - [Edition Changes](#edition-changes)
    - [System Improvements](#system-improvements)
  - [v4.1](#v41)
    - [Interface Changes](#interface-changes)
    - [Functional Changes](#functional-changes)
    - [Utility Changes](#utility-changes-1)
    - [Edition Changes](#edition-changes-1)
    - [Module Changes](#module-changes)
    - [System Changes](#system-changes)
  - [v4.1.1](#v411)
  - [v4.1.2](#v412)
  - [v5.0.0](#v500)
    - [A Brief Overview of the Work Done](#a-brief-overview-of-the-work-done)
    - [1. Core Architecture Modernization](#1-core-architecture-modernization)
    - [2. Overhaul of User Utilities and Applications](#2-overhaul-of-user-utilities-and-applications)
    - [3. User Experience (UX) and Interface Improvements](#3-user-experience-ux-and-interface-improvements)
    - [4. Build System and Code Quality Optimization](#4-build-system-and-code-quality-optimization)
    - [5. Documentation and Localization](#5-documentation-and-localization)
  - [v5.1.0](#v510)
    - [1. Build System and Code Quality Optimization](#1-build-system-and-code-quality-optimization)
    - [2. User Experience (UX) and Interface Improvements](#2-user-experience-ux-and-interface-improvements)
    - [3. System and Package Management](#3-system-and-package-management)
    - [4. Applications and Tools Updates](#4-applications-and-tools-updates)
    - [5. System Components and Documentation](#5-system-components-and-documentation)
    - [6. Dracut Integration (Experimental)](#6-dracut-integration-experimental)

## v2.2.1
- Code optimization, bug fixes.
- The adwaita-icon-theme package has been replaced with the adwaita-icon-theme-antix package, which allowed for a slight reduction in size.
- Returned the Standard greeting in the terminal.
- Added support for exFAT in the Standard and Maximum versions.
- The Standard and Maximum versions in the mausepad editor have syntax highlighting, line numbers, and the status bar enabled by default.
- Added the menulibre package to the Maximum version to edit the Whisker menu.
- Added support for Hyper-V in the Maximum version.
- In the Maximum version, VirtualBox drivers have been replaced with drivers from MX-Linux, they are better optimized for Debian.
- Added rtl8821ce and rtl8821cu drivers for Wi-Fi adapters with chips of the same name in the Maximum version.
- Support for building some modules from a running Slax system has been added to minios-live scripts.
- The ability to select the level relative to which modules will be built has been added to minios-live scripts.
- The ability to remove the dpkg database when building modules has been added to minios-live scripts.
- The ability to use third-party repositories (MX and antiX) when building the system has been added to minios-live scripts.
- An experimental ability to build based on Ubuntu 22.04 has been added to the minios-live scripts.

## v2.2.2
- Added TLP for saving laptop battery power.
- Added new wallpapers.
- Changed the appearance of the Firefox window. The tabs are now in line with the window control buttons.
- Increased compression ratio with zstd.
- In minios-live added the ability to use an alternative address of the repositories when installing the system.
- Added the ability to automatically build a system with i386 architecture without PAE.
- Replaced the theme of slim.
- Changed the themes for grub and syslinux bootloaders.
- Updated elementary-icons to version 0.16 for all system variants.
- Replaced default wallpaper.
- In minios-live, the ability to build a system without an interface with installed docker and the portainer container management web interface has been added.

## v2.3
- Different versions now use different wallpapers.
- Added the ability to build a system with a kernel that supports aufs.
- Removed dvd+rw-tools from the Minimum version.
- Added Ultra version.
- Added aufs kernel to bullseye amd64.
- Optional multilanguage support when building with minios-live scripts.
- Separate wallpapers for Fluxbox version. They are closer in color to Slax.
- Decreasing the compression ratio of zstd. Compression level 19 for Standard takes only 1 MB more than compression level 22.
- The Maximum and Ultra versions have added additional supported file systems to enable these file systems to be mounted and used by Gparted.
- Clonezilla <https://clonezilla.org> and the graphical interface for it - Rescuezilla have been added to the Maximum and Ultra versions.
- Added the ability to build a separate module for Clonezilla.
- Added the ability to build a separate module for Rescuezilla.
- Added internal site.
- Added xfce4-clipman, grsync in Maximum and Ultra versions.
- Replaced pdfmod with pdfarranger in Ultra and Maximum versions.
- Added gnumeric, abiword to Maximum version.
- Support for running scripts on system boot.
- Minimum now uses Network Manager by default.
- Automatic setting of the time zone when connecting to the network.
- Added ZFS support to Maximum and Ultra.
- New internal website.
- Fixed a bug due to which non-Latin characters could not be entered in the terminal.
- Optional support for cloud, rt kernels and kernels from backports for Debian.
- Separator "|" conflicts with grub2. We can use the "," delimiter in grub2 instead.

## v3.0
- Fixed font display in xfce4-terminal.
- Added drivers for external network adapters to initrd.
- The kernel modules is now outside the base system, making it easier to replace kernel.
- Support for rebuilding the dpkg database on boot or when hot-installing/removing modules.
- New Puzzle version.
- Standard LiveKit initrd can now be used to start MiniOS.
- UIRD initrd (https://github.com/neobht/uird) can now be used to start MiniOS.
- Added MiniOS package repository: https://minios-linux.github.io/debian
- Xorg module has been renamed to gui-base in Puzzle and contains the basic GTK3 and QT5 libraries, as well as utilities for building the interface (gtkdialog, yad).
- Fixed error parsing minios.conf configuration file.
- Restored support for Ubuntu 20.04, added support for Ubuntu 22.04.
- Fixed error loading from slow disks.
- Replaced adwaita-icon-theme and elementary-xfce-icon-theme with elementary-xfce-minios-icon-theme to reduce size and better adapt to MiniOS.
- By default, kernels with AUFS support are now used. For MiniOS, 5.10 and 6.0 kernels are built using Debian configs (https://github.com/minios-linux/aufs-kernel/releases). They can also be used in any other distribution.
- Added support for building from snapshot (https://snapshot.debian.org).
- In stretch, buster, bullseye from thunar, pcmanfm, mousepad, warning flags were removed when logging in as root.
- For the Rescuezilla module, the partclone-utils and partclone-nbd packages were compiled and added to the repository.
- Now you can disable autologin. To do this, add autologin=false in the kernel parameters or AUTOLOGIN=false in minios.conf.
- Renamed metapackages for MiniOS kernels. Now, for kernels with AUFS support, the metapackage name will be, for example: linux-image-5.10-mos-amd64.
- Remmina 1.4.27 packages built for buster.
- Inkscape 1.2.1 packages built for bullseye.
- Double Commander 1.0.8 packages built for bullseye.
- In our Slax clone (Flux) has partially translated the Russian version. If there are requests, we will translate the clone into other languages.
- fbxkb package built for bullseye and buster.
- 4 kernels (each in 3 variants) for amd64 and i386 architectures, packaged kernel modules for use in MiniOS and initrd have been added to the kernelfiles repository.
- Lightdm replaced with slim where it was used.
- At the end of the session in xfce, the hibernation and hybrid sleep buttons are no longer available (a system launched from a flash drive or from RAM cannot hibernate).
- The slax utility used to enable/disable modules has been renamed to minios-bundle to standardize MiniOS-specific console utilities.
- !!! Very big changes (2k+) in the minios-live build system. Unfortunately, it is impossible to describe them here.

## v3.1
- The LANG variable in all scripts has been replaced by LNG to avoid conflict with the system variable.
- RT, Cloud kernels are no longer present in the distribution.
- Kernels 5.10 and 6.1 of the amd64, 686, 686-pae architectures are updated to current versions.
- The splash screen on syslinux startup is now at 1024x768 instead of 640x480, and the menus have been rearranged.
- Added parameter system_type/SYSTEM_TYPE to the kernel parameters and the configuration file, which allows to switch the modules into classic mode (more details in the linux-live/buildconfig comments).
- Added console script minios-resolution, which allows to add a non-standard resolution to the screen settings (it does not work perfectly and not always, additional testing is needed).
- Optimized the code of some scripts.
- A new version of dynfilefs has been added, it is no longer necessary to specify the size of the change file, this option has been removed.

## v3.2
- Fixed some bugs that caused problems when starting the system with saving changes.
- A long process of code refactoring has been started. Useless functions will be removed from minios-live scripts, and those that remain will become more convenient, simple and clear.
- The apt2sb utility has been completely redesigned and now makes it easier to create modules from the list of packages provided to it.
- Added scr2sb utility to create modules based on the script provided to it.
- Added more detailed help in man for apt2sb and scr2sb.
- Reworked minios-geniso, minios-bundle utilities.
- Recycled utilities for working with Puzzle: minios-update-cache, minios-update-dpkg, minios-update-users. You should not run them manually, they are triggered automatically at system boot or when connecting/disconnecting modules using minios-bundle.
- Added SYSTEM_TYPE variable to minios.conf, it can also be called in kernel parameters as system_type=. It can take the values "classic" and "puzzle".
  - If "classic" is selected, all modules in the system must be built on the basis of one another. Modules built on the basis of a common module may cause errors and loss of system performance.
  - If "puzzle" is selected, then at system startup user lists are synchronized, dpkg bases from different modules are synchronized, and different caches are updated. This allows multiple modules built on the basis of a common module to work together (this is how MiniOS Puzzle works).
  - "puzzle" can be used with any variant of the system, "classic" cannot be used with MiniOS Puzzle.
  - !!! If you use the save changes mode with "puzzle" value, after the first system boot you can't add/remove modules anymore, this mode is designed to work only outside of save changes mode !!!!
- added GTK3 layout to LibreOffice module (in those MiniOS versions where it exists).
- Added EXPORT_LOGS variable in minios.conf. If it is "true", then after system startup in minios folder on flash drive there will be logs folder, where will be trace and output logs of system startup.
- Various Network Manager modules in MiniOS Puzzle are combined into one to reduce the number of layers (the more layers a system has, the more RAM it consumes).
- Updated VirtualBox installation scripts in minios-live scripts.
- Removed the CREATE_BACKUP variable, which used to be used for script backups, from buildconfig in minios-live scripts, along with its associated functionality.
- Time zone setting functionality at network startup was moved from 00-core to 00-minios, time synchronization at network startup was added.
- Added wpasupplicant to package lists (in bullseye it was installed with other packages automatically, in bookworm its absence in dependencies caused problems with Wi-Fi performance).
- In Standard and higher versions xrdp server with pulseaudio-module-xrdp is added
- In minios-live scripts instead of apt/apt-get the pkg function with similar functionality is used, thanks to which the code in scripts will be smaller
- Added install_packages function to minios-live scripts to install from package lists. Help on how to use it can be found in the function comments in minioslib
- Added a small utility to prevent windows from locking. Not included in the standard modules yet.
- Added minios-installer utility, which allows you to install the system on the foyer directly from the system.
- Updated livekitlib functions to match a future version of Slax.
- Similar to Slax, added perchsize and perchname command line parameters that allow you to specify the size of the change storage space and the name of the change storage files.
- Fixed a bug that caused NTFS booting not to work.
- Added packages for programs used in Flux to speed up building of this variant.
- Pressing F1 and F10 in the XFCE terminal no longer opens help or menus, but is handled in the terminal.
- Improved the appearance of Firefox, removing unnecessary garbage in the form of advertising links.
- Added value checker in minios.conf, which resets parameters that only accept certain values (true/false, for example) to default values on startup.
- In Flux, fixed bugs with installing a browser with Spanish language, fixed a bug where an unreveligated user was not created, which resulted in the inability to start VLC.
- Ultra adds the lazydocker utility, which allows you to conveniently monitor containers from the terminal.

## v3.3
- MiniOS boot scripts are now developed separately from Linux Live Kit (https://github.com/Tomas-M/linux-live), so they contain significantly more features.
- Most of the new features from Linux Live Kit are added.
- Fixed boot from parameter that made it impossible to change the name of the folder where the system is located.
- Added new parameters to the boot parameters, you can learn more here: https://github.com/minios-linux/minios-live/wiki/Command-line-parameters.
- Changed DPKG base building method for system type (SYSTEM_TYPE) puzzle, which speeds up operations ten times and increases reliability of base building script from modules.
- Added warning in MiniOS Installer, improved appearance.
- Battery plugin in Standard, Maximum, Ultra, Puzzle was replaced by Xfce4 Power Manager to be able to adjust backlighting.
- Added support for Portuguese (Brazil) to the build scripts.
- Updated build scripts for apt2sb, scr2sb, upg2sb modules.
- Updated utility for connecting minios-bundle modules.
- Added jq utility to core module to work with json files (they are used by some MiniOS utilities).
- In Flux:
  - removed the second Xarchiver shortcut,
  - fixed translation of some programs,
  - almost complete translation of all menus,
  - network manager icon moved from general menu to tray,
  - added Firefox browser directly to the iso.
- Added packages to the repository to simplify building Flux.
- Added fuse libraries to all editions to support AppImage.
- It should now be safe to use the puzzle system type (SYSTEM_TYPE=puzzle) in all editions (additional testing needed).
- Fixed a bug in the minios-geniso utility that made it impossible to build an iso from a system installed on a flash drive.
- Added a license file to the repository.
- Fixed README to match current version.
- Removed exfat fuse support where it is not needed.
- Added xdrp server to Maximum, Ultra, it is disabled by default, must be activated with ENABLE_SERVICES="xrdp"
- By default, ssh, docker services are disabled where they are present. If necessary, they can be activated with ENABLE_SERVICES="ssh" or ENABLE_SERVICES="docker".
- Neofetch has been added to all editions.
- In Ultra added and disabled selinux (needed for docker to work).
- Updated syslinux help.
- Icon theme updated.
- Script autorun is disabled by default.
- Updated support for the LXQT build, it is now less ugly, but still not enough.
- Optimized the build scripts to improve their performance.
- Added site translation in Chinese (Taiwan), Portuguese (Brazil).
- Added Hyper-V storage drivers for installation in a virtual machine.
- Added Galculator to Standard.
- Cleaned up minios-live code.
- Support for multi-language by installing modules.
- Kernel updated to version 6.1.52, ntfs3 support added.

## v3.3.1
- Added pt_BR translation for MiniOS Installer
- Changed logic of perchdir=askdisk behavior for compatibility with perchdir=/dev/sda1 or perchdir=/dev/disk/by-label/DiskLabel variants
- Added fonts-open-sans font set for editions with Telegram Desktop installed
- Telegram Desktop in Puzzle edition updated to version 4.8.1

## v3.3.2
- Added KDiskMark program for testing disk speed in Maximum, Ultra, Puzzle.
- Removed Gnumeric, AbiWord, PDFArranger in Maximum, added Double Commander and GNOME Nettool.
- Added several keyboard shortcuts standard for Xfce.
- Added Wireshark (traffic analysis program) and BleachBit (garbage collection program) to Maximum, Ultra, Puzzle, added shortcut to start Clonezilla.
- Added open-vm-tools-desktop to Maximum and Ultra.
- Fixed LightDM theme in editions that have LightDM.
- QT application appearance now uses the GTK theme in Standard, Maximum, Ultra, Puzzle.
- In Maximum and Ultra, xfce4-notifyd has been added.
- Pitivi has been replaced by Blender in Ultra and Puzzle (Blender has a video editor feature in addition to 3D modeling).

## v3.3.3
- In Standard, Maximum and Ultra pulseaudio-module-bluetooth has been added.
- The kernel has been updated to 6.1.67.
- Updated all packages as of the current date.
- Mini Commander was added to initrd, you can start it in debug mode with mc command.

## v3.3.4
- Restored the ability to build the distribution on the 3.3.x branch, due to a change in the repository structure it was not possible.
- Updated MiniOS Installer to a version similar to MiniOS 4.0 under development, added support for MMC devices (mmcblk) and exFAT support.
- Updated some scripts involved in system booting to fix the problem with package updates in Puzzle.
- Updated kernel to 6.1.90.
- Icon theme elementary-xfce-minios replaced by elementary-minios and updated to 0.19.
- All modules are zstd compressed in this release.
- Fixed GUI loading in Flux and Minimum.
- The gtkdialog utility from Slax has been renamed gtkask to avoid conflicts with the original GTKDialog utility.
- Improved detection of the required kernel for installation.

## v4.0

### Visual Changes
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

### General Changes
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

### Utility Changes
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

### Edition Changes
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

### System Improvements
- **Kernel Update:** The main MiniOS kernel has been updated to version 6.1.119.
- **Driver Support:** Added precompiled drivers (`rtl8188eus`, `rtl8723cs`, `rtl8812au`, and others) for the standard MiniOS kernel on amd64.
- **Storage Rights:** Enabled full user rights on FAT32, NTFS, and exFAT file systems, removing the need for root permissions.
- **Virtual Machine Enhancements:** Added automatic resolution changes in VMware, VirtualBox, KVM, and QEMU to 1280x800.

## v4.1

### Interface Changes
- Updated the appearance of the Ultra edition to match the MiniOS 4 style.
- Updated the LXQT appearance to match the MiniOS 4 style.
- Added wallpapers for the Ultra, Minimum, and Home editions.
- Added icons for PDFShuffler and QDiskInfo to the `elementary-minios` theme; the HDSentinel icon has been removed.
- If the system does not support aufs, menu items for mounting and unmounting modules will be hidden.

### Functional Changes
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

### Utility Changes
- Added the utilities `mke2fs`, `e2fsck`, `lsblk`, `parted`, `partprobe` to the initrd.
- QDiskInfo rewritten in QT5 and added to the repository.

### Edition Changes
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

### Module Changes
- Removed the `xfce-apps` module; its functions are now performed by `xfce-desktop`.
- Graphical programs not included in the DE are moved to the `apps` module.
- The `xorg` module has been replaced by `gui-base`, which contains the base libraries GTK2, GTK3, QT5, icon themes, and other components necessary for all DEs.

### System Changes
- Added `virtres` and `novirtres` to the kernel parameters.
- Added the `ntfs3-dkms` package to the repository for NTFS3 driver support in Debian kernels.
- Added quirks from the new version of libinput to support new input devices.
- Added `dnsmasq-base` to all editions.
- MiniOS kernel with AUFS support has been updated to 6.1.124.
- The pre-compiled wireless adapter modules have been replaced with DKMS modules.

## v4.1.1
- Removed `/etc/NetworkManager/dispatcher.d/09-timedate` script, because it does not allow user to set time zone by himself and automatically overrides it to the automatically defined one.
- Fixed a bug in minios-configurator that caused incorrect mapping of fields to variables in the config.
- Fixed the way `minios/minios.conf` files on the drive and `/etc/minios/minios/minios.conf` files are synchronized, because of which locale and other settings are not saved when the drive is in read-only mode.
- Updated the help command `man minios-configurator`.
- The firmware module now uses firmware from bookworm-backports.
- Added the rtw89-dkms driver to the repository.
- Fixed a bug that could cause a created user to be deleted in `puzzle` mode.
- Renamed startup.output and statrup.trace logs to minios-startup.output.log and minios-startup.output.log.
- Renamed boot.output and boot.trace logs to minios-boot.output.log and minios-boot.output.log.
- Reworked iso image file system structure, thanks to which there are no more problems with system booting from BIOS when writing to HDD using sector-by-sector copying (dd, Balena Etcher, ...).
- Added copying of ssh public keys to RAM when `toram=trim`.
- Improved user and group file merging in `puzzle` mode.
- MiniOS kernel updated to 6.1.128.
- Added a check to sb2iso that will prevent the iso from being built if the system is loaded with `toram=trim`.
- Fixed a bug in the builder in the `install_packages` function that caused packages from backports to not be installed when using the `-t` option.
- Added deletion of `/var/cache/mandb` at system build to eliminate mandb cache error when installing packages.
- Added `minios-kernelpack` utility to minios-tools to package kernel modules and create initrd.
- Added a hotkey to open the start menu.

## v4.1.2
- Added support for Ventoy-1.1.01.
- Fixed autologin under root user (https://github.com/orgs/minios-linux/discussions/68#discussioncomment-12386609).

## v5.0.0

### A Brief Overview of the Work Done

From March to August 2025, the MiniOS project underwent a fundamental modernization phase. During this period, over 600 commits were made, including more than 300 significant changes affecting all aspects of the system: from the basic architecture and build process to user applications and the visual interface.

### 1. Core Architecture Modernization

- **Transition to `live-config`:** Our `minios-boot` initialization system has been replaced by the standard Debian mechanism, `live-config`. This has unified the live system setup process, adding new capabilities while retaining old ones. `live-config` has been adapted for MiniOS needs, particularly for supporting extended configuration, settings synchronization, password setup, and options for linking/mounting user directories.
- ****

- **New Codebase:** The system is now based on **Debian 13 "Trixie"**.

- **Transition to the Debian Kernel:** We decided to abandon our custom kernel and use the standard Debian kernel in all editions. This will simplify future updates and maintain Secure Boot support.

### 2. Overhaul of User Utilities and Applications

Some key applications that come with MiniOS have been significantly redesigned, enabling modern graphical interfaces and expanded functionality. At the same time, new applications have been added that further improve usability for beginners.

- **MiniOS Installer:** The system installer has received a new, intuitive graphical interface. The installation logic has been improved, and the console mode has been removed.
- **MiniOS Configurator:** The system configurator has also been rewritten, becoming more user-friendly and functional.
- **Drive Utility:** This utility, a fork of `mintstick`, has been radically redesigned. It now features a modern graphical interface and new functionality:
  - **Image Writing:** Supports writing image files (including `.iso`, `.img`, `.bin`, and their compressed variants) to block devices.
  - **Image Creation:** Added the ability to create an image from a block device to a file, with on-the-fly compression.
  - **Secure Erase:** An integrated utility for completely wiping data from storage media.
  - **Improved Logic:** Fixed issues with disk display in virtual machines.
- **MiniOS Session Manager:** A new set of utilities for managing persistent MiniOS sessions, offering graphical `minios-session-manager` and command-line `minios-session` tools for session management.
- **MiniOS Kernel Manager:** A new set of utilities for managing Linux kernels in MiniOS, offering graphical `minios-kernel-manager` and command-line `minios-kernel` tools that allow you to package kernels from repositories or .deb files and manage different kernels on the system.

### 3. User Experience (UX) and Interface Improvements

Great attention was paid to the visual component and ease of daily use.

- **Appearance and Unification:** Work was done to unify the visual style across different desktop environments. The **Greybird** theme, which is standard for XFCE, was adapted and implemented for the **Fluxbox** desktop. This was complemented by updated wallpapers and icon sets, as well as the addition of styles for the correct appearance of QT6 applications.
- **New Icons:** Over 20 new icons for applications (including Audacity, GParted, Double Commander, VSCodium) were added as part of the `elementary-xfce-minios` theme.
- **Universal Boot Menu:** GRUB is now used as the boot menu for both UEFI and BIOS. All menu items are translated into supported languages.

### 4. Build System and Code Quality Optimization

The process of creating the distribution has become more reliable, faster, and more transparent.

- **"The Great Cleanup":** A significant amount of obsolete and unused code was removed, including old scripts for Fluxbox and duplicate configurations. This has made the codebase "lighter" and easier to maintain.
- **`CondinAPT` Implementation:** A new powerful script, `condinapt`, was developed and implemented for conditional package installation. This allowed us to move from numerous separate package lists to a single `packages.list` with flexible rules depending on the edition, architecture, and other build parameters.
- **Script Improvements:** The main `minioslib` library has been enhanced with new functions and cleaned of old code.
- **Configuration Expansion:** The `general.conf` configuration file was eliminated, and the `build.conf` file was significantly redesigned. In addition to the existing distribution, kernel, and locale settings, new parameters were added for detailed control:
- **Caching Settings:** Options for flexible cache management, including the use of `apt-cacher-ng` and creating a local repository from the package cache.
- **Interactivity and Debugging:** Long operations are now accompanied by a spinner. Additionally, a `VERBOSITY_LEVEL` setting has been added to `build.conf` to flexibly control the volume of logs during the build.

### 5. Documentation and Localization

- **Documentation:** All manuals have been updated. The documentation has been significantly expanded to describe every aspect of working with the system.
- **International Support:** Full support for the Indonesian language has been added. Existing translations (deutsch, español, français, italiano, português, português brasileiro, русский) have been updated and improved across all system components.

## v5.1.0

This release includes bug fixes for all issues discovered since v5.0.0, along with new features and improvements.

### 1. Build System and Code Quality Optimization
- **Improved Man Page Generation:** The `Makefile` and `debian/rules` have been updated to improve man page generation and localization.
- **Translation Enhancements:** The translation process has been improved, with updated `.po` files and better statistics output.
- **Package Handling:** The package installation logic has been refactored to streamline repository handling, especially for Ubuntu.
- **Code Refactoring:** Several scripts have been refactored for improved clarity, readability, and functionality.

### 2. User Experience (UX) and Interface Improvements
- **Boot Menu:** Multilingual support has been added for the SYSLINUX and GRUB boot menus.
- **Boot Parameters:** Added automatic timezone and keyboard layout configuration based on selected language in boot menu
- **Desktop Keyboard Setup:** Added automatic keyboard layout configuration in GUI from boot parameters (one-time setup)
- **Ventoy Compatibility:** Compatibility symlinks for Ventoy have been added to improve the boot experience.

### 3. System and Package Management
- **New Ubuntu Support:** Support for Ubuntu Bionic and Focal has been added to the build configuration.
- **Kernel Management:** The kernel options in `minios-cmd` have been refactored, replacing `kernel-type` with `kernel-flavour`.
- **Package Updates:** Several packages have been added and removed to optimize the different MiniOS editions. Added `firmware-mediatek` package to improve support for MediaTek wireless adapters.
- **Audio System Modernization:** Transitioned from PulseAudio to PipeWire for Standard, Toolbox, and Ultra editions, providing modern audio/video routing and lower latency.

### 4. Applications and Tools Updates

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

**Flux Tools:**
- Added Session Manager and Kernel Manager integration to fbliveapp
- Implemented gettext support for translations in fbappselect, fbdesktop, and fbliveapp scripts
- Updated French translations
- Refined VLC descriptions and installation prompts
- Lowered bash dependency to 4.4
- Added manual pages

### 5. System Components and Documentation

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

**MiniOS Configurator:**
- Added `-i/--inherit-cmdline` option to automatically inherit configuration settings from kernel command line
- Configurator detects and uses settings from the running live system when launched from installer
- Configuration is pre-filled with current boot parameters for improved installation workflow
- Added support for parsing 21 unique config parameters from kernel command line (42 cmdline parameter variants)

### 6. Dracut Integration (Experimental)
- **Dracut as Build-Time Alternative:** Experimental integration of `dracut` as an alternative `initramfs` builder option. **By default, MiniOS uses `livekit`** as the stable and production-ready initramfs builder. The `INITRAMFS_BUILDER` variable in `build.conf` allows optionally selecting `dracut` for testing purposes during system builds. Dracut support is currently **experimental and available only as a build-time option**, not in the final system.
- **Script and Configuration Updates:** Numerous scripts have been updated to support both `livekit` and `dracut`, including `minios-init`, `minios-shutdown`, and various build scripts. The system automatically detects which initramfs builder was used and adapts accordingly.
