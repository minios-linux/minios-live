#!/bin/bash

# called by dracut
check() {
    local _rootdev
    # if we don't have btrfs installed on the host system,
    # no point in trying to support it in the initramfs.
    require_binaries btrfs || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in "${host_fs_types[@]}"; do
            [[ "$fs" == "btrfs" ]] && return 0
        done
        return 255
    }

    return 0
}

# called by dracut
depends() {
    echo udev-rules
    return 0
}

# called by dracut
installkernel() {
    instmods btrfs
    # Make sure btfs can use fast crc32c implementations where available (bsc#1011554)
    instmods crc32c-intel
}

# called by dracut
install() {
    if ! inst_rules 64-btrfs.rules; then
        inst_rules "$moddir/80-btrfs.rules"
        case "$(btrfs --help)" in
            *device\ ready*)
                inst_script "$moddir/btrfs_device_ready.sh" /sbin/btrfs_finished ;;
            *)
                inst_script "$moddir/btrfs_finished.sh" /sbin/btrfs_finished ;;
        esac
    fi

    if ! dracut_module_included "systemd"; then
        inst_hook initqueue/timeout 10 "$moddir/btrfs_timeout.sh"
    fi

    inst_multiple -o btrfsck btrfs-zero-log
    inst $(command -v btrfs) /sbin/btrfs
    # Hack for slow machines
    # see https://github.com/dracutdevs/dracut/issues/658
    echo "rd.driver.pre=btrfs" > ${initdir}/etc/cmdline.d/00-btrfs.conf
}
