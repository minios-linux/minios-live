# Package List File Format for Condinaut

A package list file is a text document in which each line specifies a package (or a set of alternative packages) to be installed, along with additional conditions (filters) and, if necessary, a target release. The script processes this file, groups the lines into installation queues, and based on the filters and target release, selects which packages will be installed.

---

## 1. Line Structure

Each line (excluding comments and empty lines) consists of two main parts:

1. **Package name with optional version and target release specification.**
   - **Simple name:**
     Example:
     ```
     vim
     ```
   - **Version specification:**
     - `name=version` — the version requirement is not strict. If the required version is unavailable, the available version is installed.
       Example:
       ```
       git=2.25.1
       ```
     - `name==version` — strict requirement. If the version is not found, the installation terminates with an error.
       Example:
       ```
       curl==7.68.0
       ```
   - **Target release specification:**
     The target release is specified directly in the package name using the `@` symbol. This allows the installation to be tied to a specific repository branch.
     Example:
     ```
     telegram@bookworm-backports
     ```
     Here, the `telegram` package will be installed from the repository corresponding to the `bookworm-backports` release.

2. **Condition filters.**
   After the package name, filters are specified with a space, defining under what conditions the package will be installed. Filters compare system variable values (such as architecture, distribution, working environment) with those set in the configuration file.

---

## 2. Installation Filters

Filters allow specifying additional conditions for package selection:

- **Positive filters.**
  Start with `+` and require that the corresponding variable value matches the specified one.
  **Format:**
  ```
  +<prefix>=<value>
  ```
  **Example:**
  ```
  +da=amd64
  ```
  This filter checks that the variable corresponding to the prefix `da` (e.g., `DISTRIBUTION_ARCH`) has the value `amd64`.

- **Negative filters.**
  Start with `-` and indicate that the package should not be installed if the specified variable matches the given value.
  **Format:**
  ```
  -<prefix>=<value>
  ```
  **Example:**
  ```
  -de=flux
  ```
  If the variable `DESKTOP_ENVIRONMENT` equals `flux`, the package will not be installed.

- **Groups of alternative positive filters.**
  If at least one condition from a set must be met, filters can be grouped using `+{...}`. Conditions within the group are separated by `|`.
  **Format:**
  ```
  +{<prefix>=<value>|<prefix>=<value>|...}
  ```
  **Example:**
  ```
  +{de=gnome|de=cinnamon}
  ```
  This condition is met if `DESKTOP_ENVIRONMENT` is either `gnome` or `cinnamon`.

---

## 3. Alternatives

Different packages can be offered for the same functionality, installed depending on conditions. Alternative options are separated by the `||` operator.
**Important:** Each alternative option must include a full description — package name (with optional version and target release) and a set of filters.

**Example:**
```
nautilus +de=gnome || thunar +de=xfce
```
- If `DESKTOP_ENVIRONMENT` is `gnome`, the **nautilus** file manager is selected (typical for GNOME).
- If `DESKTOP_ENVIRONMENT` is `xfce`, **thunar** is installed (standard for XFCE).

---

## 4. Mandatory Packages

If a line starts with an exclamation mark `!`, the package is considered mandatory. If conditions are violated or the package is unavailable in the repository, the script terminates with an error.

**Example:**
```
!curl==7.68.0 +da=amd64 -de=flux
```
Here, `curl` must be installed strictly in version `7.68.0`, only for architecture `amd64`, and installation is not performed if the working environment is `flux`. If the condition is not met, the script will terminate with an error.

---

## Final Example of a Package List File

Below is an example of a package list file where all lines correspond to real usage scenarios:

```
# Network managers – selection depends on specific preferences
network-manager -de=flux || connman

# Network configuration for Ubuntu Jammy-based systems with Noble support
netplan.io +d=jammy +d=noble

# Basic system utilities
gpg
discover
laptop-mode-tools
kbd
keyboard-configuration
laptop-detect
locales
console-setup
man-db
pciutils
usbutils
dnsmasq-base
squashfs-tools
xorriso
mc

# Terminal utilities with support for various functional sets
bash-completion +pv=ultra +pv=toolbox +pv=standard
ncdu +pv=ultra +pv=toolbox +pv=standard

# File managers: selection depends on the working environment
nautilus +de=gnome || thunar +de=xfce

# Telegram messenger installed from backports for Bookworm
telegram@bookworm-backports +de=gnome

# Other packages
htop
gddrescue +pv=ultra +pv=toolbox
rsync +pv=ultra +pv=toolbox
netcat +pv=ultra +pv=toolbox
netcat-openbsd +pv=ultra +pv=toolbox
ssh
```

In this example:
- **Alternatives** are implemented for network connection managers and file managers based on the working environment.
- **Target release** for the `telegram` package is specified directly in its name.
- **Filters** set additional installation conditions, such as architecture selection, version, or functional set.