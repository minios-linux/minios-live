## 🏗️ Building MiniOS with `minios-live`

`minios-live` is a step-by-step build tool that uses pre-defined configurations to create a customized MiniOS live system. This allows for a more controlled and modular build process, including the ability to add software layered on top of the base system using SquashFS modules.

### Build Options

Using `minios-live`, you can build the following configurations:

- **Debian 12, Debian 13, Debian Unstable with Xfce4 environment**.
- **Debian 12 with Fluxbox environment** (analogous to [Slax](https://www.slax.org/)).
- **Debian 12 with LXQT environment**.

### Prerequisites

- It is advisable to use the latest version of Debian or Ubuntu for building.
- ⚠️ **WARNING**: Never run scripts from the `linux-live` folder directly. It will break your system.

### Build Commands

`minios-live` breaks down the build process into discrete steps:

- **`build-bootstrap`** - Installs a minimal base system using `debootstrap`.
- **`build-chroot`** - Installs the remaining core components and chosen desktop environment within the chroot environment.
- **`build-live`** - Creates the main SquashFS image containing the core MiniOS system.
- **`build-modules`** - Builds additional SquashFS modules containing extra software packages. These modules are layered on top of the main SquashFS image, providing a modular way to add functionality without rebuilding the entire core system.
- **`build-boot`** - Copies the boot files, generates the initrd and the necessary boot configuration files.
- **`build-iso`** - Creates the final ISO image, incorporating both the core SquashFS image and any additional modules.

### Command Syntax

```bash
./minios-live [start_cmd] [-] [end_cmd]
```

* **`start_cmd`**: (Optional) The build stage to start from. If omitted, and no other arguments are provided, displays the help information. If omitted *with* other arguments present (like `-` or `end_cmd`), starts from the beginning (`setup_host`).
* **`-`**: (Optional) A range operator. When used with both `start_cmd` and `end_cmd`, runs all commands between them.
* **`end_cmd`**: (Optional) The build stage to end with. If omitted, runs to the end (`build-iso`).

**How the command syntax works:**

* **No commands specified (`./minios-live`):** Displays help information.
* **Only `start_cmd`:** Runs only the specified command.  Example: `./minios-live build-chroot` runs only the `build-chroot` stage.
* **Only `end_cmd`:** Runs from the beginning up to and including the specified command. Example: `./minios-live - build-live` runs everything up to and including `build-live`.
* **`start_cmd`, `-`, and `end_cmd`:** Runs all commands starting from `start_cmd` up to and including `end_cmd`.  Example: `./minios-live build-bootstrap - build-live` runs everything from `build-bootstrap` to `build-live`.
* **`start_cmd` and `-` (no `end_cmd`):** Runs from `start_cmd` to the end of the build process. Example: `./minios-live build-modules -` runs from `build-modules` to `build-iso`.
* **`-` (only the hyphen):** Runs the entire build process, equivalent to specifying all stages or omitting all arguments.


### Quick Start & Configuration

Edit the configuration file  `linux-live/build.conf` to specify your preferred distribution, desktop environment, and additional software to be included in the SquashFS modules. Then, to build the entire system, run:

```bash
./minios-live -
```

This modular approach allows for greater flexibility and maintainability when customizing your MiniOS live system. You can easily add or update software by modifying the SquashFS module configurations and rebuilding only the affected modules using the appropriate `minios-live` command.
