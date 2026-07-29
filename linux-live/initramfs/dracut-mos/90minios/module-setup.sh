#!/bin/bash
# MiniOS dracut module

check() {
    return 0
}

depends() {
    echo base
    echo fs-lib
    return 0
}

install_bundled_crypt() {
    local payload=$1 manifest="$1/../buildroot/crypt_payload.sha256" path
    local files=(
        usr/sbin/cryptsetup usr/sbin/dmsetup sbin/losetup
        lib/libc.so lib/ld-musl-i386.so.1
        usr/lib/libcryptsetup.so.12 usr/lib/libcryptsetup.so.12.11.0
        usr/lib/libpopt.so.0 usr/lib/libpopt.so.0.0.2
        lib/libuuid.so.1 lib/libuuid.so.1.3.0
        lib/libblkid.so.1 lib/libblkid.so.1.1.0
        usr/lib/libdevmapper.so.1.02 usr/lib/libargon2.so.1
        usr/lib/libjson-c.so.5 usr/lib/libjson-c.so.5.4.0
        lib/libsmartcols.so.1 lib/libsmartcols.so.1.1.0
    )

    for path in "${files[@]}"; do
        [ -e "$payload/$path" ] || [ -L "$payload/$path" ] || return 1
    done
    if [ ! -f "$manifest" ] || ! (cd "$payload" && sha256sum -c "$manifest" >/dev/null); then
        echo "E: Bundled crypto payload failed integrity verification" >&2
        return 1
    fi
    [ "$(readlink "$payload/lib/ld-musl-i386.so.1")" = libc.so ] || return 1
    [ "$(readlink "$payload/lib/libblkid.so.1")" = libblkid.so.1.1.0 ] || return 1
    [ "$(readlink "$payload/lib/libsmartcols.so.1")" = libsmartcols.so.1.1.0 ] || return 1
    [ "$(readlink "$payload/lib/libuuid.so.1")" = libuuid.so.1.3.0 ] || return 1
    [ "$(readlink "$payload/usr/lib/libcryptsetup.so.12")" = libcryptsetup.so.12.11.0 ] || return 1
    [ "$(readlink "$payload/usr/lib/libjson-c.so.5")" = libjson-c.so.5.4.0 ] || return 1
    [ "$(readlink "$payload/usr/lib/libpopt.so.0")" = libpopt.so.0.0.2 ] || return 1
    (cd "$payload" && cp -a --parents "${files[@]}" "$initdir")
}

install() {
    # Install dracut hooks
    inst_hook cmdline 30 "$moddir/parse-minios.sh"
    inst_hook mount 30 "$moddir/minios-mount-root.sh"
    inst_hook shutdown 20 "$moddir/minios-shutdown.sh"

    if [ -d "/run/initramfs/dracut-mos" ]; then
        STATIC_BIN="/run/initramfs/bin"
        LIVEKITLIB="/run/initramfs/usr/lib/livekitlib"
        TERMINFO="/run/initramfs/usr/share/terminfo/l/linux"
        DRACUT_MOS="/run/initramfs/dracut-mos"
    elif [ -d "/linux-live/initramfs/dracut-mos" ]; then
        STATIC_BIN="/linux-live/initramfs/livekit-mos/bin"
        LIVEKITLIB="/linux-live/initramfs/livekit-mos/lib/livekitlib"
        TERMINFO="/linux-live/initramfs/livekit-mos/usr/share/terminfo/l/linux"
        DRACUT_MOS="/linux-live/initramfs/dracut-mos"
    fi

    # Install minios-init
    inst_script "$moddir/minios-init" "/minios-init"

    # Install essential static binaries for initramfs
    inst_simple "$STATIC_BIN/busybox" "/bin/busybox"
    inst_simple "$STATIC_BIN/eject" "/bin/eject"
    inst_simple "$STATIC_BIN/mke2fs" "/bin/mke2fs"
    inst_simple "$STATIC_BIN/resize2fs" "/bin/resize2fs"
    inst_simple "$STATIC_BIN/e2fsck" "/bin/e2fsck"
    inst_simple "$STATIC_BIN/jq" "/bin/jq"
    inst_simple "$STATIC_BIN/mc" "/bin/mc"
    inst_simple "$STATIC_BIN/blkid" "/bin/blkid"
    inst_simple "$STATIC_BIN/lsblk" "/bin/lsblk"
    inst_simple "$STATIC_BIN/parted" "/bin/parted"
    inst_simple "$STATIC_BIN/partprobe" "/bin/partprobe"
    inst_simple "$STATIC_BIN/ncurses-menu" "/bin/ncurses-menu"
    inst_simple "$STATIC_BIN/@mount.httpfs2" "/bin/@mount.httpfs2"
    inst_simple "$STATIC_BIN/@mount.ntfs-3g" "/bin/@mount.ntfs-3g"
    inst_simple "$STATIC_BIN/dynblk" "/bin/dynblk"
    ln -sf dynblk "${initdir}/bin/@mount.dynfilefs"
    inst_simple "$STATIC_BIN/minios-boot" "/bin/minios-boot"

    if [ "$MINIOS_CRYPT" = "true" ]; then
        install_bundled_crypt "${STATIC_BIN%/bin}" ||
            inst_multiple cryptsetup dmsetup losetup || return 1
        touch "${initdir}/etc/minios-initramfs-crypt"
    fi

    # Install livekitlib
    inst_simple "$LIVEKITLIB" "/lib/livekitlib"

    # Install minios-release
    inst_simple /etc/minios-release /etc/minios-release

    # Create initrd-release
    {
        echo "NAME=MiniOS"
        echo "ID=minios"
        echo "PRETTY_NAME=\"MiniOS Linux\""
    } >"${initdir}/etc/initrd-release"

    # Install terminfo
    inst_simple "$TERMINFO" "/usr/share/terminfo/l/linux"

    # Install whole dracut-mos tree into the initramfs
    cp -r "$DRACUT_MOS" "${initdir}/dracut-mos"
    chmod 755 "${initdir}/dracut-mos/mkdracut"

    # Create memory directories
    inst_dir /memory/{changes,data,bundles,overlay}

    # Create busybox symlinks
    "${initdir}/bin/busybox" | grep , | grep -v Copyright | tr "," " " | while read LINE; do
        for TOOL in $LINE; do
            [ ! -e "${initdir}/bin/$TOOL" ] && ln -s busybox "${initdir}/bin/$TOOL"
        done
    done
    rm -f "${initdir}/"{s,}bin/init

    # Use busybox ash as /bin/sh
    ln -sf busybox "${initdir}/bin/sh"
    ln -sf busybox "${initdir}/bin/ash"

    # Wrap systemd-udevd to suppress version message
    if [ -f /usr/lib/systemd/systemd-udevd ] && [ ! -f /usr/lib/systemd/systemd-udevd.real ]; then
        inst_simple /usr/lib/systemd/systemd-udevd /usr/lib/systemd/systemd-udevd.real
        inst_simple "$moddir/systemd-udevd-wrapper" /usr/lib/systemd/systemd-udevd
        chmod 755 "${initdir}/usr/lib/systemd/systemd-udevd"
    fi

    return 0
}

# Explicit kernel module selection - matches livekit approach
installkernel() {
    # Filesystems
    instmods squashfs overlay loop zram aufs
    instmods ext2 ext3 ext4 fat vfat ntfs ntfs3 exfat
    instmods isofs fuse efivarfs btrfs xfs
    instmods nls_cp437 nls_iso8859-1 nls_utf8

    # Compression and checksums
    instmods =crypto/lz4 =crypto/zstd
    instmods crc32c crc32c-intel crc32-pclmul crc32c_generic

    # Block devices
    instmods nbd dm-mod
    instmods =drivers/block/zram =drivers/block/loop
    instmods =drivers/staging/zsmalloc
    if [ "$MINIOS_CRYPT" = "true" ]; then
        instmods dm-crypt =crypto || return 1
    fi

    # USB support
    instmods =drivers/usb/storage =drivers/usb/host
    instmods =drivers/usb/common =drivers/usb/core
    instmods =drivers/hid/usbhid
    instmods hid hid-generic uhid

    # Storage controllers
    instmods =drivers/cdrom
    instmods sr_mod sd_mod scsi_mod sg
    instmods =drivers/ata =drivers/nvme =drivers/mmc

    # Hyper-V
    instmods hv_storvsc

    # Cloud/VM support
    if [ "$MINIOS_CLOUD" = "true" ]; then
        instmods virtio virtio_mmio virtio_pci virtio_ring
        instmods =drivers/virtio
        instmods virtio_blk virtio_scsi
        instmods vmw_pvscsi
    fi

    # Network support
    if [ "$MINIOS_NETWORK" = "true" ]; then
        instmods =drivers/net/ethernet
        instmods =drivers/net/phy

        # Cloud network drivers
        if [ "$MINIOS_CLOUD" = "true" ]; then
            instmods =drivers/net/vmxnet3
            instmods virtio_net
        fi
    fi

    # DKMS modules
    instmods ntfs3

    return 0
}
