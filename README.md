# ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/minios-linux/minios-live/total?style=for-the-badge&logoSize=30&label=%20TOTAL%20DOWNLOADS&labelColor=white&color=orange)

![MiniOS](images/minios.png)

MiniOS aims to provide users with a reliable, user-friendly portable system with a graphical interface. These scripts build a bootable MiniOS ISO image.

## 🌐 Useful Resources

If you want to learn how to use MiniOS, there are several helpful resources to get you started.

### 🖥️ Official MiniOS Website

On the [official MiniOS website](https://minios.dev), you will find information about the different editions of the system and their features.

- **Community Support**: Access to forums and community resources for additional help and support.
- **Edition Features**: Comparison of features available in each edition.
- **Download Links**: Direct links to download ISO images of each version.

### 📚 Official Wiki

For the necessary information on how to use MiniOS, visit the [official Wiki](https://github.com/minios-linux/minios-live/wiki). Here you will find detailed instructions, guides, and tips on installing and configuring the system.

- **Installation**: Step-by-step guides on installing MiniOS in various ways.
- **Configuration**: Tips and recommendations on configuring the system to suit your needs.
- **Customization**: How to personalize MiniOS.
- **Modules**: Information on creating and using modules.

## 🏗️ Building MiniOS

### Build Options

Using `minios-live`, you can build the following configurations:

- **Debian 10, Debian 12, Debian Unstable, and Ubuntu 22.04 with Xfce4 environment**.
- **Debian 12 with Fluxbox environment** (analogous to [Slax](https://www.slax.org/)).
- **Debian 12 with LXQT environment**.

### Prerequisites

- It is advisable to use the latest version of Debian or Ubuntu for building.
- ⚠️ **WARNING**: Never run scripts from the `linux-live` folder directly. It will break your system.

### Build Commands

To start the build process, use the following commands:

- **`setup_host`** - Install packages required for building on the host.
- **`build_bootstrap`** - Install a minimal system using `debootstrap`.
- **`build_chroot`** - Install the remaining components required to start the system.
- **`build_live`** - Build the SquashFS image.
- **`build_modules`** - Build additional modules.
- **`build_iso`** - Build the final ISO image.

### Command Syntax

```sh
./minios-live [start_cmd] [-] [end_cmd]
```

- **start_cmd**: The command to start from (optional).
- **-**: Execute all commands between `start_cmd` and `end_cmd`.
- **end_cmd**: The command to end with (optional).

#### Examples

- Run all commands:
  
  ```sh
  ./minios-live -
  ```

- Run from `build_bootstrap` to `build_chroot`:
  
  ```sh
  ./minios-live build_bootstrap - build_chroot
  ```

- Run up to `build_chroot`:
  
  ```sh
  ./minios-live - build_chroot
  ```

- Run from `build_bootstrap` to the end:
  
  ```sh
  ./minios-live build_bootstrap -
  ```

- Run only `build_iso`:
  
  ```sh
  ./minios-live build_iso
  ```

### Quick Start

To build the system from the beginning, edit `linux-live/build.conf` and `linux-live/general.conf` and run:

```sh
./minios-live -
```

## 📖 Step-by-Step Build Guide

### Step 1: Configuration

To build, change the parameters in the `linux-live/config` file to select the desired option. This file allows you to configure various aspects of the build process, such as the distribution, desktop environment, and system settings. Key configuration options include:

- **Distribution**: Specifies the base distribution (e.g., Debian or Ubuntu) and its version.
- **Architecture**: Defines the target architecture (e.g., amd64, i386).
- **Desktop Environment**: Chooses the desktop environment (e.g., XFCE, Fluxbox).
- **Package Variant**: Selects the set of packages to include (e.g., standard, minimum).
- **Kernel Options**: Configures the kernel type and version.
- **Localization**: Sets the locale and timezone.
- **User Settings**: Configures default user and password.
- **Build Options**: Includes settings for module compression, union file system type, and ISO naming.

### Step 2: Setup Host

Install the necessary packages on the host system:

```sh
./minios-live setup_host
```

This command will ensure your host system has all the required tools and dependencies to proceed with the build.

### Step 3: Build Bootstrap

Install a minimal system using `debootstrap`:

```sh
./minios-live build_bootstrap
```

This step will create the initial file system with the basic Debian or Ubuntu system.

### Step 4: Build Chroot

Install the remaining components required to start the system:

```sh
./minios-live build_chroot
```

This step adds additional software and configurations to the minimal system created in the previous step.

### Step 5: Build Live

Create the SquashFS image:

```sh
./minios-live build_live
```

This step compresses the file system into a SquashFS image, which is used for the live environment.

### Step 6: Build Modules

Build the additional modules:

```sh
./minios-live build_modules
```

Modules in MiniOS are compressed SquashFS files that contain specific parts of the operating system. These modules can include the kernel, firmware, desktop environments, applications, and other components. Each module is built in sequence and can be updated or replaced independently. Here is an example of the modules included in MiniOS Standard:

- **00-core-amd64-zstd.sb**: Core system files. Built using the `build_bootstrap`-`build_live` commands.
- **00-minios-amd64-zstd.sb**: Essential MiniOS components.
- **01-kernel-6.1.90-mos-amd64-zstd.sb**: Kernel modules.
- **02-firmware-amd64-zstd.sb**: Firmware for various hardware components.
- **03-xorg-amd64-zstd.sb**: Xorg display server, Blackbox window manager and xterm terminal emulator.
- **04-xfce-desktop-amd64-zstd.sb**: XFCE desktop environment.
- **05-xfce-apps-amd64-zstd.sb**: Applications for the XFCE environment.
- **06-firefox-amd64-zstd.sb**: Firefox web browser.

The modules are built in sequence, and if a module is already built, it is skipped. The `build_modules` command handles this process automatically.

### Step 7: Build ISO

Build the final ISO image:

```sh
./minios-live build_iso
```

This command generates the bootable ISO image that can be used to create bootable USB drives or CDs.

## ✍️ Author

Created by [crims0n](https://github.com/crim50n). For more information, visit [minios.dev](https://minios.dev).
