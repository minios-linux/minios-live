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
    local payload=$1 list="$1/../buildroot/crypt_payload_files.txt" path

    [ -f "$list" ] || return 1
    while IFS= read -r path; do
        [ -e "$payload/$path" ] || [ -L "$payload/$path" ] || return 1
    done <"$list"
    tar -C "$payload" -cf - -T "$list" | tar -C "$initdir" -xf -
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
    inst_simple "$STATIC_BIN/unsquashfs" "/bin/unsquashfs"
    inst_simple "$STATIC_BIN/mc" "/bin/mc"
    inst_simple "$STATIC_BIN/blkid" "/bin/blkid"
    inst_simple "$STATIC_BIN/lsblk" "/bin/lsblk"
    inst_simple "$STATIC_BIN/parted" "/bin/parted"
    inst_simple "$STATIC_BIN/partprobe" "/bin/partprobe"
    inst_simple "$STATIC_BIN/ncurses-menu" "/bin/ncurses-menu"
    inst_simple "$STATIC_BIN/@mount.httpfs2" "/bin/@mount.httpfs2"
    inst_simple "$STATIC_BIN/@mount.ntfs-3g" "/bin/@mount.ntfs-3g"
    inst_simple "$STATIC_BIN/dynfilefs" "/bin/dynfilefs"
    ln -sf dynfilefs "${initdir}/bin/@mount.dynfilefs"
    inst_simple "$STATIC_BIN/minios-boot" "/bin/minios-boot"

    if [ "$MINIOS_CRYPT" = "true" ]; then
        install_bundled_crypt "${STATIC_BIN%/bin}" ||
            inst_multiple cryptsetup || return 1
        printf '%s\n' 'luks-layer-v1' >"${initdir}/etc/minios-initramfs-crypt"
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

normalize_dynblk_module() {
    local source="" candidate target count=0
    [ -d "${initdir}/lib/modules" ] || return 0
    while IFS= read -r candidate; do
        [ -f "$candidate" ] || continue
        source="$candidate"
        count=$((count + 1))
    done < <(find "${initdir}/lib/modules" -type f \
        \( -name 'dynblk.ko' -o -name 'dynblk.ko.gz' -o -name 'dynblk.ko.xz' -o -name 'dynblk.ko.zst' \))
    [ "$count" -eq 0 ] && return 0
    if [ "$count" -ne 1 ]; then
        echo "E: Multiple dynblk module files found in initramfs input" >&2
        return 1
    fi
    target="${source%.gz}"
    target="${target%.xz}"
    target="${target%.zst}"
    case "$source" in
        *.ko) return 0 ;;
        *.ko.gz) gzip -cd "$source" >"$target.tmp" ;;
        *.ko.xz) xz -cd "$source" >"$target.tmp" ;;
        *.ko.zst) zstd -cd "$source" >"$target.tmp" ;;
        *) return 1 ;;
    esac
    mv "$target.tmp" "$target"
    rm -f "$source"
    chmod 0644 "$target"
}

# Explicit kernel module selection - matches livekit approach
installkernel() {
    local dynblk_bin=""

    # Filesystems
    instmods squashfs overlay loop zram aufs aufs-ng
    instmods -o dynblk
    normalize_dynblk_module || return 1
    if find "${initdir}/lib/modules" -type f -name 'dynblk.ko' -print -quit | grep -q .; then
        if [ -x /run/initramfs/bin/dynblk ]; then
            dynblk_bin=/run/initramfs/bin/dynblk
        elif [ -x /linux-live/initramfs/livekit-mos/bin/dynblk ]; then
            dynblk_bin=/linux-live/initramfs/livekit-mos/bin/dynblk
        else
            echo "E: dynblk.ko is present but the initramfs dynblk binary is missing" >&2
            return 1
        fi
        inst_simple "$dynblk_bin" "/bin/dynblk"
        touch "${initdir}/etc/minios-initramfs-dynblk"
    fi
    instmods ext2 ext3 ext4 fat vfat ntfs ntfs3 exfat
    instmods isofs fuse efivarfs btrfs xfs
    instmods nls_cp437 nls_iso8859-1 nls_utf8

    # Compression and checksums
    instmods =crypto/lz4 =crypto/zstd
    instmods -o lz4hc lzo lzo-rle deflate
    instmods -o crc32c-intel
    instmods -o crc32-pclmul
    instmods -o crc32c_generic

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
