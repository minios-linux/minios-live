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

install() {
    inst_hook cmdline 30 "$moddir/parse-minios.sh"
    inst_hook mount 30 "$moddir/minios-mount-root.sh"
    inst_hook shutdown 20 "$moddir/minios-shutdown.sh"
    inst_script "$moddir/minios-init" "/minios-init"

    # Set static binaries directory
    local STATIC_BIN=""

    if [ -d "${moddir}/../../../../../linux-live/initramfs/livekit-mos/bin" ]; then
        STATIC_BIN="${moddir}/../../../../../linux-live/initramfs/livekit-mos/bin"
    fi

    if [ -z "$STATIC_BIN" ] || [ ! -x "$STATIC_BIN/busybox" ]; then
        derror "CRITICAL: Static binaries directory not found!"
        derror "Expected location:"
        derror "  - livekit-mos/bin (standalone mode)"
        return 1
    fi

    dinfo "*** Found static binaries at: $STATIC_BIN"

    # Install essential static binaries for initramfs
    inst_simple "$STATIC_BIN/busybox" "/bin/busybox"
    inst_simple "$STATIC_BIN/eject" "/bin/eject"
    inst_simple "$STATIC_BIN/mke2fs" "/bin/mke2fs"
    inst_simple "$STATIC_BIN/resize2fs" "/bin/resize2fs"
    inst_simple "$STATIC_BIN/e2fsck" "/bin/e2fsck"
    inst_simple "$STATIC_BIN/mc" "/bin/mc"
    inst_simple "$STATIC_BIN/blkid" "/bin/blkid"
    inst_simple "$STATIC_BIN/lsblk" "/bin/lsblk"
    inst_simple "$STATIC_BIN/parted" "/bin/parted"
    inst_simple "$STATIC_BIN/partprobe" "/bin/partprobe"
    inst_simple "$STATIC_BIN/ncurses-menu" "/bin/ncurses-menu"
    inst_simple "$STATIC_BIN/@mount.httpfs2" "/bin/@mount.httpfs2"
    inst_simple "$STATIC_BIN/@mount.ntfs-3g" "/bin/@mount.ntfs-3g"
    inst_simple "$STATIC_BIN/@mount.dynfilefs" "/bin/@mount.dynfilefs"

    # Find and install livekitlib
    local LIVEKITLIB_SRC=""

    if [ -f "${moddir}/../../../../../linux-live/initramfs/livekit-mos/lib/livekitlib" ]; then
        LIVEKITLIB_SRC="${moddir}/../../../../../linux-live/initramfs/livekit-mos/lib/livekitlib"
    elif [ -f "/lib/livekitlib" ]; then
        LIVEKITLIB_SRC="/lib/livekitlib"
    fi

    if [ -z "$LIVEKITLIB_SRC" ] || [ ! -f "$LIVEKITLIB_SRC" ]; then
        derror "CRITICAL: livekitlib not found!"
        derror "Expected locations:"
        derror "  - livekit-mos/lib/livekitlib"
        derror "  - /lib/livekitlib"
        return 1
    fi

    inst_simple "$LIVEKITLIB_SRC" "/lib/livekitlib"

    if [ ! -f "${initdir}/lib/livekitlib" ]; then
        derror "CRITICAL: Failed to install livekitlib!"
        return 1
    fi

    # Install minios-boot if available
    if [ -x "$STATIC_BIN/minios-boot" ]; then
        inst_simple "$STATIC_BIN/minios-boot" "/bin/minios-boot"
    fi

    [ -f /etc/minios-release ] && inst_simple /etc/minios-release /etc/minios-release

    {
        echo "NAME=MiniOS"
        echo "ID=minios"
        echo "PRETTY_NAME=\"MiniOS Linux\""
    } >"${initdir}/etc/initrd-release"

    # Install terminfo
    local TERMINFO_PATHS=(
        "${moddir}/../usr/share/terminfo/l/linux"
        "/usr/share/terminfo/l/linux"
    )

    for TERMPATH in "${TERMINFO_PATHS[@]}"; do
        if [ -f "$TERMPATH" ]; then
            inst_simple "$TERMPATH" "/usr/share/terminfo/l/linux"
            break
        fi
    done

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
    if [ -f /usr/lib/systemd/systemd-udevd ]; then
        # Install real udevd binary with .real suffix
        inst_simple /usr/lib/systemd/systemd-udevd /usr/lib/systemd/systemd-udevd.real
        # Install wrapper script that suppresses stderr
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
