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
artifacts from `output/target` to `livekit-mos/bin`. The committed payload is
tracked directly by Git; no separate checksum manifest is maintained for files
already stored in the repository.

Validate it with `initramfs/tests/run.sh --strict` on a host with Bats,
ShellCheck, cryptsetup, and root privileges.

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
