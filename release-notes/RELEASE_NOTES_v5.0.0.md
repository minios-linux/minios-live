# Release Notes v5.0.0

## A Brief Overview of the Work Done

From March to August 2025, the MiniOS project underwent a fundamental modernization phase. During this period, over 600 commits were made, including more than 300 significant changes affecting all aspects of the system: from the basic architecture and build process to user applications and the visual interface.

## 1. Core Architecture Modernization

- **Transition to `live-config`:** Our `minios-boot` initialization system has been replaced by the standard Debian mechanism, `live-config`. This has unified the live system setup process, adding new capabilities while retaining old ones. `live-config` has been adapted for MiniOS needs, particularly for supporting extended configuration, settings synchronization, password setup, and options for linking/mounting user directories.
- **New Codebase:** The system is now based on **Debian 13 "Trixie"**.
- **Transition to the Debian Kernel:** We decided to abandon our custom kernel and use the standard Debian kernel in all editions. This will simplify future updates and maintain Secure Boot support.

## 2. Overhaul of User Utilities and Applications

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

## 3. User Experience (UX) and Interface Improvements

Great attention was paid to the visual component and ease of daily use.

- **Appearance and Unification:** Work was done to unify the visual style across different desktop environments. The **Greybird** theme, which is standard for XFCE, was adapted and implemented for the **Fluxbox** desktop. This was complemented by updated wallpapers and icon sets, as well as the addition of styles for the correct appearance of QT6 applications.
- **New Icons:** Over 20 new icons for applications (including Audacity, GParted, Double Commander, VSCodium) were added as part of the `elementary-xfce-minios` theme.
- **Universal Boot Menu:** GRUB is now used as the boot menu for both UEFI and BIOS. All menu items are translated into supported languages.

## 4. Build System and Code Quality Optimization

The process of creating the distribution has become more reliable, faster, and more transparent.

- **"The Great Cleanup":** A significant amount of obsolete and unused code was removed, including old scripts for Fluxbox and duplicate configurations. This has made the codebase "lighter" and easier to maintain.
- **`CondinAPT` Implementation:** A new powerful script, `condinapt`, was developed and implemented for conditional package installation. This allowed us to move from numerous separate package lists to a single `packages.list` with flexible rules depending on the edition, architecture, and other build parameters.
- **Script Improvements:** The main `minioslib` library has been enhanced with new functions and cleaned of old code.
- **Configuration Expansion:** The `general.conf` configuration file was eliminated, and the `build.conf` file was significantly redesigned. In addition to the existing distribution, kernel, and locale settings, new parameters were added for detailed control:
- **Caching Settings:** Options for flexible cache management, including the use of `apt-cacher-ng` and creating a local repository from the package cache.
- **Interactivity and Debugging:** Long operations are now accompanied by a spinner. Additionally, a `VERBOSITY_LEVEL` setting has been added to `build.conf` to flexibly control the volume of logs during the build.

## 5. Documentation and Localization

- **Documentation:** All manuals have been updated. The documentation has been significantly expanded to describe every aspect of working with the system.
- **International Support:** Full support for the Indonesian language has been added. Existing translations (deutsch, español, français, italiano, português, português brasileiro, русский) have been updated and improved across all system components.
