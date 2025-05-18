### Module Build Script Folder Structure

Each module is located in the directory:

```
linux-live/scripts/##-module-name
```

Below is the basic structure and purpose of each element inside the module directory:

```
<MODULE_NAME>/
├── rootcopy-install/                 # (optional) Files copied before installation
│   └── ...                           # Can contain a nested directory tree
├── install                           # Installation script in chroot
│   └── packages.list                 # List of basic packages for installation
├── patches/                          # (optional) Patches for the module source code
│   └── ...                           # *.patch, structured by necessary paths
├── build                             # Module build script inside chroot
│   └── is_dkms_build                 # DKMS build flag (empty file)
├── rootcopy-postinstall/             # (optional) Files copied after post-install
│   └── ...                           # Same as rootcopy-install
├── postinstall                       # (optional) Post-installation script in chroot

```

### Component Description

* **rootcopy-install/**: Folder for files that need to be copied directly to the root system inside chroot before (`install`).

* **install**: Executable module installation script. Copies files, installs dependencies, configures the environment. Runs first.

* **packages.list**: APT package list for installation using `condinaut`.

* **patches/**: Directory with patches that will be applied before building (the patch application code should be described in `build`). The structure retains relative paths, and patches are copied inside chroot into the `/patches/` folder. Not available for `00-core`.

* **build**: Executable script (chmod +x), runs inside chroot after environment preparation. Compilation, configuration, and other module build stages take place here. Installed packages are not saved in the DPKG database. Not available for `00-core`.

* **is\_dkms\_build**: Empty tag file. If present, DKMS logic is used: only compiled kernel modules are saved in the squashfs module. Not available for `00-core`.

* **rootcopy-postinstall/**: Folder for files that need to be copied directly to the root system inside chroot before (`postinstall`). Used for replacing files from installed packages.

* **postinstall**: Script executed after main installation and cleanup. Used for additional configurations (modifying configuration files and other actions where cleanup is not required).

### Adding a Module to the Distribution

Navigate to the folder of the required environment:

```
cd linux-live/environments/xfce
```

Create a symbolic link to the module creation scripts (example for the `virt-manager` module, whose creation scripts should be in the folder `linux-live/scripts/10-virt-manager`).

```
ln -s ../../scripts/10-virt-manager
```

or, if you want to change the module's sequence number,

```
ln -s ../../scripts/10-virt-manager 07-virt-manager
```

**Note:** You can learn more about the rules of scripting on the example of the `install` script.
