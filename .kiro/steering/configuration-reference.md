# Configuration Reference

## build.conf Variables

### Distribution Settings
| Variable | Description | Options |
|----------|-------------|---------|
| `DISTRIBUTION` | Target distribution | buster, bullseye, bookworm, trixie, sid, jammy, noble |
| `DISTRIBUTION_ARCH` | Architecture | amd64, i386, i386-pae |
| `DESKTOP_ENVIRONMENT` | Desktop environment | xfce, flux, lxqt, core |
| `PACKAGE_VARIANT` | Package set | minimum, standard, toolbox, ultra |
| `COMP_TYPE` | Compression | zstd, xz, lzo, gz, lz4 |

### Kernel Settings
| Variable | Description | Options |
|----------|-------------|---------|
| `INSTALL_KERNEL` | Install kernel | true, false |
| `KERNEL_FLAVOUR` | Kernel type | none, rt, cloud |
| `KERNEL_AUFS` | AUFS support | true, false |
| `KERNEL_BUILD_DKMS` | Build DKMS modules | true, false |

### Locale & Timezone
| Variable | Description | Options |
|----------|-------------|---------|
| `LOCALE` | System locale | C, en_US, ru_RU, de_DE, es_ES, fr_FR, it_IT, pt_BR |
| `MULTILINGUAL` | Multi-language support | true, false |
| `KEEP_LOCALES` | Retain all locales | true, false |
| `LIVE_TIMEZONE` | Timezone | Etc/UTC, Europe/Moscow, etc. |

### Boot Loader Settings
| Variable | Description | Options |
|----------|-------------|---------|
| `INITRAMFS_BUILDER` | Initramfs type | livekit, dracut |
| `BOOTLOADER` | Boot loader config | grub-only, syslinux-grub, syslinux-native |
| `MENU_LANG` | Boot menu language | multilang, en_US, ru_RU, etc. |
| `NAMED_BOOT_FILES` | Version in boot filenames | true, false |

### Live System Settings
| Variable | Description | Options |
|----------|-------------|---------|
| `LIVE_HOSTNAME` | System hostname | string |
| `LIVE_USERNAME` | Default user | string |
| `LIVE_USER_DEFAULT_GROUPS` | User groups | comma-separated |
| `LIVE_USER_PASSWORD_CRYPTED` | User password hash | yescrypt hash |
| `LIVE_ROOT_PASSWORD_CRYPTED` | Root password hash | yescrypt hash |
| `DEFAULT_TARGET` | Systemd target | graphical, multi-user |
| `ENABLE_SERVICES` | Services to enable | comma-separated |
| `DISABLE_SERVICES` | Services to disable | comma-separated |

### Builder Settings
| Variable | Description | Options |
|----------|-------------|---------|
| `VERBOSITY_LEVEL` | Output verbosity | 0, 1, 2 |
| `BUILD_TEST_ISO` | Create test ISO | true, false |
| `REMOVE_OLD_ISO` | Clean old ISOs | true, false |
| `SKIP_SETUP_HOST` | Skip host setup | true, false |
| `REMOVE_SOURCES` | Cleanup sources | true, false |
| `FILTER_MODULES` | Filter module level | true, false |
| `FILTER_LEVEL` | Max module level | 0-9 |

### Cache Settings
| Variable | Description | Options |
|----------|-------------|---------|
| `USE_ROOTFS` | Use cached rootfs | true, false |
| `USE_APT_CACHE` | Cache apt packages | true, false |
| `USE_APT_CACHE_REPO` | Use local repo cache | true, false |
| `USE_APT_CACHER` | Use apt-cacher-ng | true, false |
| `APT_CACHER_ADDRESS` | Cacher proxy address | IP:PORT |

## Supported Locales

The `LOCALES` array in minioslib defines:
- Keyboard layout code
- Keyboard layout name
- Firefox locale (Debian/Ubuntu)
- LibreOffice locale

Available: C, de_DE, en_US, es_ES, fr_FR, it_IT, pt_BR, ru_RU

## Password Generation

Generate yescrypt password hash:
```bash
echo "password" | mkpasswd --method=yescrypt --stdin
```

For legacy distributions (Debian 10):
```bash
echo "password" | mkpasswd --method=sha-512 --stdin
```

## Distribution URLs

Automatically set based on distribution:
- Debian: `http://deb.debian.org/debian`
- Ubuntu: `http://archive.ubuntu.com/ubuntu`
- Kali: `http://archive.kali.org/kali`
- Snapshot builds: `https://snapshot.debian.org/archive/debian/`
