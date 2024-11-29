# ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/minios-linux/minios-live/total?style=for-the-badge&logoSize=30&label=%20TOTAL%20DOWNLOADS&labelColor=white&color=orange)

![MiniOS](images/minios.png)

MiniOS is a reliable and user-friendly portable system with a graphical interface. These scripts build a bootable MiniOS ISO image.

## 🌐 Resources

Learn more about using and building MiniOS:

### 🖥️ Official Website

The [official website](https://minios.dev) is your central hub for information about MiniOS.  Find details on the different editions available, their respective features, community forums for support, and direct download links for the ISO images.

### 📚 Official Wiki

The [official Wiki](https://github.com/minios-linux/minios-live/wiki) provides in-depth knowledge and practical guidance for working with MiniOS. Explore comprehensive guides covering installation procedures, system configuration, customization options, and how to extend functionality with modules.

### 🛠️ Building MiniOS

MiniOS provides two powerful tools for building customized ISO images:

- **`minios-cmd`:**  This command-line utility simplifies the configuration and initiation of builds.  It provides a user-friendly interface for setting various build parameters like the target distribution, architecture, desktop environment, kernel options, locale, and more.  `minios-cmd` then uses these parameters to generate a configuration file for `minios-live` and automatically triggers the build process.  [Learn more about building with `minios-cmd`](docs/minios-cmd.md).

- **`minios-live`:** This script orchestrates the step-by-step build process. It handles tasks such as setting up the build environment, installing the base system, integrating the chosen desktop environment, creating the SquashFS filesystem, configuring the boot process, and finally generating the bootable ISO image.  [Learn more about building with `minios-live`](docs/minios-live.md).


## ✍️ Author

Created by [crims0n](https://github.com/crim50n).  Learn more at [minios.dev](https://minios.dev).