#!/bin/bash

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    echo base
    echo fs-lib
    return 0
}

# called by dracut
install() {
    # Install cmdline parser
    inst_hook cmdline 30 "$moddir/parse-minios.sh"

    # Install mount hook that defines mount_root() function
    inst_hook mount 30 "$moddir/minios-mount-root.sh"

    # Install main init script
    inst_script "$moddir/minios-init" "/minios-init"

    # Find livekit-mos bin directory with static binaries
    # During build in chroot: BUILD_SCRIPTS is set (e.g., "linux-live")
    # moddir = /usr/lib/dracut/modules.d/90minios
    local LIVEKIT_BIN=""

    # First priority: use BUILD_SCRIPTS environment variable (set during build)
    if [ -n "${BUILD_SCRIPTS:-}" ] && [ -d "/${BUILD_SCRIPTS}/initramfs/livekit-mos/bin" ]; then
        LIVEKIT_BIN="/${BUILD_SCRIPTS}/initramfs/livekit-mos/bin"
    # Second: try common build location
    elif [ -d "/build/minios-live/linux-live/initramfs/livekit-mos/bin" ]; then
        LIVEKIT_BIN="/build/minios-live/linux-live/initramfs/livekit-mos/bin"
    # Third: relative to module directory
    elif [ -d "${moddir}/../../../../initramfs/livekit-mos/bin" ]; then
        LIVEKIT_BIN="${moddir}/../../../../initramfs/livekit-mos/bin"
    # Fourth: try /run/initramfs (if running from live system)
    elif [ -d "/run/initramfs/bin" ]; then
        LIVEKIT_BIN="/run/initramfs/bin"
    fi

    if [ -z "$LIVEKIT_BIN" ] || [ ! -x "$LIVEKIT_BIN/busybox" ]; then
        derror "CRITICAL: livekit-mos bin directory not found!"
        derror "Searched paths:"
        derror "  - /${BUILD_SCRIPTS:-BUILD_SCRIPTS_not_set}/initramfs/livekit-mos/bin"
        derror "  - /build/minios-live/linux-live/initramfs/livekit-mos/bin"
        derror "  - ${moddir}/../../../../initramfs/livekit-mos/bin"
        derror "  - /run/initramfs/bin"
        return 1
    fi

    dinfo "Found livekit-mos binaries at: $LIVEKIT_BIN"

    # Install static binaries from livekit-mos (same as mkinitrfs)
    # These are all 32-bit statically linked binaries - self-contained, no dependencies

    # Core tools (from FILES array in mkinitrfs)
    inst_simple "$LIVEKIT_BIN/busybox" "/bin/busybox"
    inst_simple "$LIVEKIT_BIN/eject" "/bin/eject"
    inst_simple "$LIVEKIT_BIN/mke2fs" "/bin/mke2fs"
    inst_simple "$LIVEKIT_BIN/resize2fs" "/bin/resize2fs"
    inst_simple "$LIVEKIT_BIN/e2fsck" "/bin/e2fsck"
    inst_simple "$LIVEKIT_BIN/mc" "/bin/mc"
    inst_simple "$LIVEKIT_BIN/blkid" "/bin/blkid"
    inst_simple "$LIVEKIT_BIN/lsblk" "/bin/lsblk"
    inst_simple "$LIVEKIT_BIN/parted" "/bin/parted"
    inst_simple "$LIVEKIT_BIN/partprobe" "/bin/partprobe"
    inst_simple "$LIVEKIT_BIN/ncurses-menu" "/bin/ncurses-menu"

    # MiniOS-specific mount helpers
    inst_simple "$LIVEKIT_BIN/@mount.httpfs2" "/bin/@mount.httpfs2"
    inst_simple "$LIVEKIT_BIN/@mount.ntfs-3g" "/bin/@mount.ntfs-3g"
    inst_simple "$LIVEKIT_BIN/@mount.dynfilefs" "/bin/@mount.dynfilefs"

    # Install additional required commands from system
    # These are provided by dracut or need to be system binaries
    inst_multiple mount umount modprobe losetup mksquashfs
    inst_multiple swapon mkswap switch_root pivot_root

    # Optional: network tools (only if network module is loaded)
    # udhcpc wget tftp ifconfig route - provided by dracut network module

    # Install livekitlib - core library for MiniOS boot logic
    # During build, build-initramfs already copies it to /lib/livekitlib
    # Otherwise try to find it from source locations
    local LIVEKITLIB_SRC=""

    # First: check if already installed by build-initramfs
    if [ -f "/lib/livekitlib" ]; then
        LIVEKITLIB_SRC="/lib/livekitlib"
    # Second: use BUILD_SCRIPTS environment variable
    elif [ -n "${BUILD_SCRIPTS:-}" ] && [ -f "/${BUILD_SCRIPTS}/initramfs/livekit-mos/lib/livekitlib" ]; then
        LIVEKITLIB_SRC="/${BUILD_SCRIPTS}/initramfs/livekit-mos/lib/livekitlib"
    # Third: try common build location
    elif [ -f "/build/minios-live/linux-live/initramfs/livekit-mos/lib/livekitlib" ]; then
        LIVEKITLIB_SRC="/build/minios-live/linux-live/initramfs/livekit-mos/lib/livekitlib"
    # Fourth: relative to module directory
    elif [ -f "${moddir}/../../../../initramfs/livekit-mos/lib/livekitlib" ]; then
        LIVEKITLIB_SRC="${moddir}/../../../../initramfs/livekit-mos/lib/livekitlib"
    fi

    if [ -z "$LIVEKITLIB_SRC" ] || [ ! -f "$LIVEKITLIB_SRC" ]; then
        derror "CRITICAL: livekitlib not found!"
        derror "Searched locations:"
        derror "  - /lib/livekitlib (copied by build-initramfs)"
        derror "  - /${BUILD_SCRIPTS:-BUILD_SCRIPTS_not_set}/initramfs/livekit-mos/lib/livekitlib"
        derror "  - /build/minios-live/linux-live/initramfs/livekit-mos/lib/livekitlib"
        derror "  - ${moddir}/../../../../initramfs/livekit-mos/lib/livekitlib"
        return 1
    fi

    dinfo "Installing livekitlib from: $LIVEKITLIB_SRC"
    inst_simple "$LIVEKITLIB_SRC" "/lib/livekitlib"

    # Verify installation
    if [ ! -f "${initdir}/lib/livekitlib" ]; then
        derror "CRITICAL: Failed to install livekitlib to initramfs!"
        return 1
    fi

    # Install MiniOS boot script
    if [ -f "$LIVEKIT_BIN/minios-boot.sh" ]; then
        inst_simple "$LIVEKIT_BIN/minios-boot.sh" "/bin/minios-boot"
        chmod +x "$initdir/bin/minios-boot"
    elif [ -x "$LIVEKIT_BIN/minios-boot" ]; then
        inst_simple "$LIVEKIT_BIN/minios-boot" "/bin/minios-boot"
    fi

    # Install configuration
    [ -f /etc/minios-release ] && inst_simple /etc/minios-release /etc/minios-release

    # Create /etc/initrd-release - REQUIRED for initrd-switch-root.target
    # Without this, systemd won't allow switching to real root
    {
        echo "NAME=MiniOS"
        echo "ID=minios"
        echo "PRETTY_NAME=\"MiniOS Linux\""
    } > "${initdir}/etc/initrd-release"

    # Install terminfo for proper terminal support
    local TERMINFO_PATHS=(
        "/build/minios-live/linux-live/initramfs/livekit-mos/usr/share/terminfo/l/linux"
        "${moddir}/../../livekit-mos/usr/share/terminfo/l/linux"
        "/usr/share/terminfo/l/linux"
    )

    for TERMPATH in "${TERMINFO_PATHS[@]}"; do
        if [ -f "$TERMPATH" ]; then
            inst_simple "$TERMPATH" "/usr/share/terminfo/l/linux"
            break
        fi
    done

    # Create directories
    inst_dir /lib/live
    inst_dir /lib/live/mount
    inst_dir /lib/live/mount/changes
    inst_dir /lib/live/mount/medium
    inst_dir /lib/live/mount/bundles
    inst_dir /lib/live/mount/overlay

    # Create busybox symlinks
    "${initdir}/bin/busybox" | grep , | grep -v Copyright | tr "," " " | while read LINE; do
        for TOOL in $LINE; do
            if [ ! -e "${initdir}/bin/$TOOL" ]; then
                ln -s busybox "${initdir}/bin/$TOOL"
            fi
        done
    done
    rm -f "${initdir}/"{s,}bin/init

    return 0
}

# called by dracut
installkernel() {
    # Install AUFS/OverlayFS modules
    instmods aufs overlay
    
    # Install squashfs support
    instmods squashfs
    
    # Install filesystem modules
    instmods ext4 ext3 ext2 vfat ntfs ntfs3 exfat fuseblk
    
    # Install loop device support
    instmods loop
    
    # Install block device modules
    instmods sd_mod usb_storage uas
    
    # Install ZRAM support
    instmods zram zsmalloc
    
    # Install network modules if needed
    instmods e1000 e1000e r8169 igb ixgbe
    
    return 0
}
