## 🏗️ Building MiniOS with `minios-cmd`

`minios-cmd` is a command-line utility designed to simplify the process of configuring and building customized MiniOS system images. Acting as a frontend for `minios-live`, it manages the configuration and invokes `minios-live` to execute the actual build steps.

---

### Build Options

With `minios-cmd`, you can customize various aspects of your MiniOS image, including:

- **Distribution:** Choose from Debian and Ubuntu releases (e.g., `bookworm`, `jammy`, `trixie`).
- **Architecture:** Specify the target architecture (e.g., `amd64`, `i386`).
- **Desktop Environment:** Select your preferred desktop environment (e.g., `xfce`, `lxqt`).
- **Package Variant:** Use pre-defined package sets like `standard` or `toolbox`.
- **Compression Type:** Specify the image compression method (e.g., `zstd`).
- **Kernel:** Configure kernel type, enable backports, AUFS support, and DKMS module compilation.
- **Locale and Timezone:** Set the system locale and timezone.

---

### Syntax

The basic syntax for `minios-cmd` is:

```bash
minios-cmd [OPTIONS]
```

---

### Options

#### Required Options
These options **must be provided** unless a configuration file is used:

- `-d, --distribution NAME`: Specify the distribution (e.g., `bookworm`).
- `-a, --architecture NAME`: Specify the architecture (e.g., `amd64`).
- `-de, --desktop-environment NAME`: Select the desktop environment (e.g., `xfce`).
- `-pv, --package-variant NAME`: Choose the package variant (e.g., `standard`).

#### Optional Options

- **Configuration Options:**
  - `--config-file FILE`: Use a configuration file (ignores all other options).
  - `--config-only`: Generate a configuration file without building the image.

- **Build Options:**
  - `-b, --build-dir DIR`: Specify the build directory.

- **Kernel Options:**
  - `-kt, --kernel-type NAME`: Specify the kernel type (e.g., `default`).
  - `-bpo, --kernel-backports`: Enable kernel backports.
  - `-aufs, --kernel-aufs`: Enable AUFS support.
  - `-dkms, --kernel-build-dkms`: Compile additional drivers with DKMS.

- **Locale and Timezone Options:**
  - `-l, --locale NAME`: Set the system locale (e.g., `en_US`).
  - `-ml, --multilingual`: Enable multilingual support.
  - `-kl, --keep-locales`: Retain all available locales.
  - `-tz, --timezone NAME`: Specify the timezone (e.g., `Etc/UTC`).

- **Compression Option:**
  - `-c, --compression-type NAME`: Specify compression type (e.g., `zstd`).

---

### Interaction with `minios-live`

`minios-cmd` prepares the build environment and generates a `build.conf` configuration file based on the options provided. It then calls `minios-live` with the relevant environment variables, delegating the build execution to `minios-live`.

---

### Quick Start Examples

#### Minimal Build
Build a MiniOS system with Ubuntu 22.04, amd64 architecture, XFCE desktop, and the standard package variant:

```bash
minios-cmd -d jammy -a amd64 -de xfce -pv standard
```

#### Customized Build
Build a MiniOS system with Debian 12, amd64 architecture, XFCE desktop, the toolbox package variant, zstd compression, and a Russian locale:

```bash
minios-cmd -d bookworm -a amd64 -de xfce -pv toolbox -c zstd -l ru_RU
```

#### Kernel Backports
Enable the kernel from backports:

```bash
minios-cmd -d bookworm -a amd64 -de xfce -pv standard -bpo
```

#### Multilingual Support
Enable multilingual support: This option generates system locales for English, Spanish, German, French, Italian, Brazilian Portuguese, and Russian, while removing all other unused locales.

```bash
minios-cmd -d trixie -a amd64 -de xfce -pv standard -ml
```

---

### Generating and Using Configuration Files

#### Generate a Configuration File

```bash
minios-cmd --config-only --config-file myconfig.conf -d bookworm -a amd64 -de xfce -pv standard
```

#### Use the Configuration File with `minios-live`

```bash
BUILD_CONF=/path/to/myconfig.conf ./minios-live -
```

or:

```bash
export BUILD_CONF=/path/to/myconfig.conf
./minios-live -
```

---

### Additional Resources

For more advanced configurations and the most up-to-date information, refer to the `minios-cmd` help:

```bash
minios-cmd --help
```

