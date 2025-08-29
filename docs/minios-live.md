## 🏗️ Building MiniOS with `minios-live`

`minios-live` is a step-by-step build tool that builds bootable MiniOS ISO images. It uses pre-defined configurations to create a customized MiniOS live system with a controlled and modular build process, including the ability to add software layered on top of the base system using SquashFS modules.

### Build Options

Using `minios-live`, you can build various configurations including:

- **Debian distributions:** Buster (10), Bullseye (11), Bookworm (12), Trixie (13)
- **Ubuntu distributions:** Jammy (22.04), Noble (24.04)  
- **Desktop environments:** 
  - **Debian:** Xfce (standard), Flux (minimum), LXQt (Bookworm/Trixie only)
  - **Ubuntu:** Xfce only
- **Package variants:** 
  - **All Debian:** Standard (xfce), Minimum (flux)
  - **Bookworm/Trixie only:** Toolbox, Ultra
  - **Ubuntu:** Standard only
- **Architectures:** amd64, i386 (for older distributions)

### Prerequisites

- It is advisable to use the latest version of Debian or Ubuntu for building.
- ⚠️ **WARNING**: Never run scripts from the `linux-live` folder directly. It will break your system.

### Supported Commands

`minios-live` breaks down the build process into discrete steps:

- **`build-bootstrap`** - Installs a minimal base system using `debootstrap`
- **`build-chroot`** - Installs the remaining core components and chosen desktop environment within the chroot environment
- **`build-live`** - Creates the main SquashFS image containing the core MiniOS system
- **`build-modules`** - Builds additional SquashFS modules containing extra software packages
- **`build-boot`** - Copies the boot files, generates the initrd and the necessary boot configuration files  
- **`build-config`** - Generates configuration files for the build
- **`build-iso`** - Creates the final ISO image, incorporating both the core SquashFS image and any additional modules
- **`remove-sources`** - Removes source files after the build

### Usage

```bash
./minios-live [start_cmd] [-] [end_cmd]
```

**Parameters:**
- **`start_cmd`**: (Optional) The build stage to start from. If omitted, starts from the first command
- **`-`**: (Optional) A range operator for running command sequences  
- **`end_cmd`**: (Optional) The build stage to end with. If omitted, ends with the last command

**How it works:**
- **No arguments (`./minios-live`)**: Displays help information
- **Single command**: Runs only that specific command
- **`start_cmd - end_cmd`**: Runs all commands from start_cmd to end_cmd
- **`- end_cmd`**: Runs from the beginning up to end_cmd
- **`start_cmd -`**: Runs from start_cmd to completion
- **`-` only**: Runs the entire build process from start to finish


### Examples

#### Complete Build
Run the build from start to finish:
```bash
./minios-live -
```

#### Partial Build Range  
Start the build by building the base environment and finish by installing the entire system in chroot:
```bash
./minios-live build-bootstrap - build-chroot
```

#### Build from Beginning to Specific Step
Start the build from the beginning and finish by installing the entire system in chroot:
```bash
./minios-live - build-chroot
```

#### Build from Specific Step to End
Start the build by building the base environment and run to completion:
```bash
./minios-live build-bootstrap -
```

#### Single Step Build
Build only ISO image from previously prepared data:
```bash
./minios-live build-iso
```

### Configuration

Edit the configuration file `linux-live/build.conf` to specify your preferred distribution, desktop environment, and additional software to be included in the SquashFS modules. Alternatively, use `minios-cmd` for an easier configuration experience.

This modular approach allows for greater flexibility and maintainability when customizing your MiniOS live system. You can easily add or update software by modifying the SquashFS module configurations and rebuilding only the affected modules using the appropriate `minios-live` command.
