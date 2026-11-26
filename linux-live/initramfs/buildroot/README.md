# Reproducible initrd tools

The bundled `mke2fs`, `e2fsck`, `resize2fs`, `jq`, `mksquashfs`, and
`unsquashfs` are built from Buildroot 2025.02.16, which pins e2fsprogs
1.47.2, jq 1.7.1, and squashfs-tools 4.6.1. The target is static i686/musl
and optimized for initrd size without disabling ext4, SquashFS compressor,
or xattr support.

## Static payload

```sh
curl -fLO https://buildroot.org/downloads/buildroot-2025.02.16.tar.gz
printf '%s  %s\n' \
  9dbc803fe020926cb1518c149466709576d19b94d4f806d8eb7ff354f3f16414 \
  buildroot-2025.02.16.tar.gz | sha256sum -c -
tar -xzf buildroot-2025.02.16.tar.gz
cd buildroot-2025.02.16
patch -p1 < /path/to/initramfs/buildroot/0001-e2fsprogs-minimize-static-tools.patch
cp /path/to/initramfs/buildroot/initrd_tools_defconfig configs/minios_initrd_tools_defconfig
make minios_initrd_tools_defconfig
make
output/host/opt/ext-toolchain/bin/i686-buildroot-linux-musl-strip \
  --strip-all --remove-section=.comment \
  --remove-section=.note output/target/sbin/mke2fs \
  output/target/sbin/e2fsck output/target/sbin/resize2fs \
  output/target/usr/bin/jq output/target/usr/bin/mksquashfs \
  output/target/usr/bin/unsquashfs
```

The resulting tools are static 32-bit i386/musl executables. Copy the required
artifacts from `output/target` to `livekit-mos/bin`. Build the bundled dynblk CLI
with the same Buildroot target toolchain, then strip it with the matching target
stripper:

```sh
output/host/bin/i686-linux-gcc -Os -ffunction-sections -fdata-sections \
  -std=gnu11 -Wall -Wextra -Werror -D_FILE_OFFSET_BITS=64 -DDYNBLK_NO_DYNAMIC_CODECS -static \
  -Wl,--gc-sections \
  /path/to/submodules/dynblk/dynblk_cli.c \
  /path/to/submodules/dynblk/dynblk_common.c \
  /path/to/submodules/dynblk/dynblk_check.c \
  /path/to/submodules/dynblk/dynblk_engine.c \
  /path/to/submodules/dynblk/dynblk_host.c \
  /path/to/submodules/dynblk/lzo/decompress.c \
  -o /path/to/initramfs/livekit-mos/bin/dynblk
output/host/bin/i686-linux-strip --strip-all \
  --remove-section=.comment --remove-section=.note \
  /path/to/initramfs/livekit-mos/bin/dynblk
```

The committed payload is tracked directly by Git; no separate checksum manifest
is maintained for files already stored in the repository.

Validate it with `initramfs/tests/run.sh --strict` on a host with Bats,
ShellCheck, cryptsetup, and root privileges.

## Mini Commander

The initrd `bin/mc` uses unchanged Mini Commander v2.3 source, commit
`f5024ed4bdee4645a906e2526115defd2f2415f9` from `Tomas-M/mini-commander`.
This is separate from the Debian package, which installs `/usr/bin/mini-cmd`.
Use the verified Buildroot 2025.02.16 archive and Bootlin i686/musl
`2024.05-1` toolchain above. Buildroot pins ncurses to 6.4-20230603.
Run as the unprivileged `builder` in the prepared Trixie development container,
with private source/output directories rather than the working checkout:

```sh
# Inside the verified, freshly extracted Buildroot source directory:
cp /path/to/initramfs/buildroot/mc_defconfig configs/minios_mc_defconfig
make O=/path/to/mc-output minios_mc_defconfig
make O=/path/to/mc-output ncurses
/path/to/initramfs/buildroot/build-mc.sh \
  /path/to/mc-output /path/to/mini-commander-source /path/to/result/mc
```

`build-mc.sh` uses `-Os`, function/data sections, static ncursesw, linker
section garbage collection and the matching target stripper. It checks ELF32,
x86 and the absence of a dynamic interpreter or shared dependencies before
atomically replacing its destination. No UPX or application source patch is
used. Keep `usr/share/terminfo/l/linux` with the payload: this build reads
terminfo files rather than embedding terminal profiles. Both LiveKit and
Dracut already include the Linux console description; other terminal types
need their corresponding entry.

Before replacing `livekit-mos/bin/mc`, run the packaging repository's
`debian/tests/file-operations.py /path/to/result/mc` with `LC_ALL=C.UTF-8`.
Also check Linux-console startup and UTF-8 editing in a minimal root with
only the binary, a root account entry and the bundled Linux terminfo, without
shared libraries. Run the initramfs suite in strict mode afterwards. Updating
this source payload does not regenerate existing initrd or ISO images.

## Crypto payload

The optional crypto payload is built separately because cryptsetup's LVM2 and
libargon2 dependencies prevent a fully static Buildroot configuration. It uses
the same i686/musl toolchain and contains cryptsetup 2.8.4 and its shared-library
closure.

```sh
cp /path/to/initramfs/buildroot/crypt_tools_defconfig configs/minios_crypt_tools_defconfig
cp /path/to/initramfs/LVM2.2.03.27.tgz dl/
make minios_crypt_tools_defconfig
make
tar -C output/target -cf - \
  -T /path/to/initramfs/buildroot/crypt_payload_files.txt | \
  tar -C /path/to/initramfs/livekit-mos -xf -
```

`LVM2.2.03.27.tgz` has SHA-256
`3133415905b9b46d152d064865d52f32eee4fcbeb0e8a69e3510caeaae0c56a9`.

The regular files in the payload total 2,451,100 bytes. A deterministic tar
archive is 1,222,853 bytes with gzip `-9` and 965,488 bytes with xz `-9`.
`crypt_payload_files.txt` is the complete copy list used by both initramfs
builders. The payload itself is tracked by Git, and the contract tests verify
that every listed file exists and that the shared-library symlink closure is
valid.
