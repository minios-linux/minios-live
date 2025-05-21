# Module Building

## Module Build Script Folder Structure

Each module is located in the directory:

```
linux-live/scripts/##-module-name
```

Below is the basic structure and purpose of each element inside the module directory:

```
<MODULE_NAME>/
├── skip_conditions.conf              # (optional) Skipping conditions file
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

*Notes:*

* In the example folder, the `build` script is renamed to `build_` because the `virt-manager` build used in the example does not need to compile the source code.

## Component Description

* **skip_conditions.conf**: A file specifying the conditions under which module building will be skipped. Building will be skipped if any of the conditions coincide.

* **rootcopy-install/**: Folder for files that need to be copied directly to the root system inside chroot before (`install`).

* **install**: Executable module installation script. Copies files, installs dependencies, configures the environment. Runs first.

* **packages.list**: APT package list for installation using `condinaut`.

* **patches/**: Directory with patches that will be applied before building (the patch application code should be described in `build`). The structure retains relative paths, and patches are copied inside chroot into the `/patches/` folder. Not available for `00-core`.

* **build**: Executable script (chmod +x), runs inside chroot after environment preparation. Compilation, configuration, and other module build stages take place here. Installed packages are not saved in the DPKG database. Not available for `00-core`.

* **is\_dkms\_build**: Empty tag file. If present, DKMS logic is used: only compiled kernel modules are saved in the squashfs module. Not available for `00-core`.

* **rootcopy-postinstall/**: Folder for files that need to be copied directly to the root system inside chroot before (`postinstall`). Used for replacing files from installed packages.

* **postinstall**: Script executed after main installation and cleanup. Used for additional configurations (modifying configuration files and other actions where cleanup is not required).

## Adding a Module to the Distribution

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

---

*Notes:*

* You can get more information about creating modules in the script comments.

## Module Naming

**Module Types:**

* **Base Modules (01–09):** sequentially numbered, any gaps are restored automatically.
* **Additional Modules (≥10):** retain their original numbering; may include information from a `.package` file.

### 1. Ranges and Purposes

* **01–09** — base modules, key components of the system.
* **10 and above** — additional modules that extend functionality.

### 2. General File Name Template

1. The directory name is used, e.g., `04-xfce-desktop`.
2. The architecture is appended (`$DISTRIBUTION_ARCH`, e.g., `amd64`).
3. The extension is added (`$BEXT`, e.g., `sb`).

> **Result:** `04-xfce-desktop-amd64.sb`

### 3. Base Modules (01–09)

1. **Numbering:** the prefix `0N` is taken from the directory name.
2. **Gap Restoration:** if there's a gap in the sequence (e.g., modules `01`, `02`, `04`), the new module will take the first free number (`03` in this case).
3. This mechanism restores logical and visual sequence if any module (e.g., `02`) was excluded from the build.
4. **If there are no gaps:** the module receives the next available number in order.

### 4. Additional Modules (≥10)

1. **Original Numbering:** the directory number is used as-is.
2. **`.package` File Support:** if a `.package` file exists in the module directory, values are read:

   ```ini
   PACKAGE=virt-manager
   VERSION=1-4.1.0-2
   ```

   The name is formed using the template: `<NN>-<package>-<version>.<bext>`

   In this case, the final name will be: `10-virt-manager-1-4.1.0-2-amd64.sb`

### 5. Examples

##### Module Directories:

```
01-kernel/
02-firmware/
03-gui-base/
04-xfce-desktop/
05-apps/
06-firefox/
10-virt-manager/
```

#### Example 1: Base Module with a Gap

If `skip_conditions.conf` specifies that the module `05-apps` should be skipped for `PACKAGE_VARIANT=standard`, its directory is excluded from the build.

As a result, the module `06-firefox/` gets the name:

```
05-firefox-amd64.sb
```

Because it moves up to fill the vacant position 05.

#### Example 2: All Modules Included

If no module is excluded, then `06-firefox/` retains its original name:

```
06-firefox-amd64.sb
```

#### Example 3: Additional Module without `.package`

If the directory `10-virt-manager/` has no `.package` file, the name is formed as:

```
10-virt-manager-amd64.sb
```

#### Example 4: Additional Module with `.package`

If the directory `10-virt-manager/` contains a `.package` file with the following content:

```ini
PACKAGE=virt-manager
VERSION=1-4.1.0-2
```

Then the module name will be:

```
10-virt-manager-1-4.1.0-2-amd64.sb
```

---

*Notes:*

* Numeric prefixes in module names define their loading order.
* Automatic restoration of gaps among base modules ensures a stable and readable image structure.
