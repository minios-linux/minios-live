# Encrypted Initrd Persistence

Set `INITRAMFS_CRYPT="true"` to pass `--crypt` to either initramfs builder.
The builders prefer the verified i686/musl payload laid out under `livekit-mos`
and fall back to copying host tools and their dependencies. The build still
fails early if `cryptsetup`, `dmsetup`, or `losetup` is unavailable on the build
host. The initrd includes those tools, their dynamic-library closure, `dm-crypt`
and crypto kernel modules, and `/etc/minios-initramfs-crypt`.

At boot, use `perchmode=luks`. Like every `perch*` parameter, this enables
persistence. The mode uses only
`changes/<session>/changes.luks`; it never formats or opens a LUKS partition and
does not use raw or DynFileFS containers. The pipeline is file, owned loop,
LUKS2, owned mapper, ext4, then the changes mount.

`perchsize` follows the existing raw-mode units: the default is 4000 MiB, the maximum is 1000000 MiB,
and FAT32 containers are capped at 4000 MiB. A container grows only when a larger
size is requested, never shrinks, and its apparent file size is exactly the
selected `truncate SIZE M` size. New containers prompt for a password and confirmation;
existing containers permit three unlock attempts. Passwords are supplied only on
the initramfs TTY, never in command arguments or logs. If encrypted persistence
cannot be activated, MiniOS warns the user and continues with temporary in-memory
changes; it never silently creates unencrypted persistence. Owned mapper and loop names
are recorded under `/run/initramfs/minios-crypt` and are closed in reverse order
by both initrd shutdown implementations.
