# Static initrd tools

The bundled `mke2fs`, `e2fsck`, `resize2fs`, and `jq` are built from Buildroot
2025.02.16, which pins e2fsprogs 1.47.2 and jq 1.7.1. The target is static
i686/musl and optimized for initrd size without disabling ext4 features.

```sh
curl -fLO https://buildroot.org/downloads/buildroot-2025.02.16.tar.gz
printf '%s  %s\n' \
  9dbc803fe020926cb1518c149466709576d19b94d4f806d8eb7ff354f3f16414 \
  buildroot-2025.02.16.tar.gz | sha256sum -c -
tar -xzf buildroot-2025.02.16.tar.gz
cd buildroot-2025.02.16
patch -p1 < /path/to/initramfs/buildroot/0001-e2fsprogs-minimize-static-tools.patch
cp /path/to/initramfs/buildroot/resize2fs_defconfig configs/minios_resize2fs_defconfig
make minios_resize2fs_defconfig
make
host/opt/ext-toolchain/bin/i686-buildroot-linux-musl-strip \
  --strip-all --remove-section=.comment \
  --remove-section=.note target/sbin/mke2fs target/sbin/e2fsck \
  target/sbin/resize2fs target/usr/bin/jq
```

Expected artifact:

```text
ELF 32-bit LSB Intel i386, statically linked, stripped
mke2fs:    638408 bytes  73442ff03f5c47606c785c118182bc35b44a0ffe57929ddb44137ed175941043
e2fsck:    802184 bytes  e027bb18dd2677df0bd02e99a34701e8a4a95ab3349162fea11e9f94e5803835
resize2fs: 333568 bytes  d6d28764a7f8ee5c72a91bb1a25d06bbfd4401d12eef865512db385884f1273f
jq:        406812 bytes  b848d1820063c6ce15af1168b726e8b241cb8f83bf0b02009b7c3999f1d64039
```

`initrd_bins.sha256` covers every executable in `livekit-mos/bin`, including
tools built outside this Buildroot configuration. The contract tests verify
both the hashes and that the manifest lists the complete executable set.

Validate it with `initramfs/tests/run.sh --strict` on a host with Bats,
ShellCheck, cryptsetup, root privileges, and a free loop device.

## Crypto payload

The optional crypto payload is built separately because cryptsetup's LVM2 and
libargon2 dependencies prevent a fully static Buildroot configuration. It uses
the same i686/musl toolchain and contains only cryptsetup 2.8.4, dmsetup from
LVM2 2.03.27, losetup from util-linux 2.40.4, and their unique shared-library
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

The regular files in the payload total 2,670,920 bytes. A deterministic tar
archive is 1,313,988 bytes with gzip `-9` and 1,015,140 bytes with xz `-9`.
Verify the bundled files with:

```sh
cd /path/to/initramfs/livekit-mos
sha256sum -c ../buildroot/crypt_payload.sha256
```

The contract tests also verify the seven shared-library symlink targets.
