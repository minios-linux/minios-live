#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    WORK=$(mktemp -d)
}

teardown() {
    rm -rf "$WORK"
}

contains() {
    grep -Fq -- "$2" "$1"
}

@test "LiveKit and in-tree Dracut init paths use shared persistence before the union" {
    for init in "$ROOT/livekit-mos/init" "$ROOT/dracut-mos/90minios/minios-init"; do
        contains "$init" '. /lib/livekitlib'
        contains "$init" 'persistent_changes "$DATA" "$CHANGES"'
        contains "$init" 'init_union "$CHANGES" "$UNION" "$BUNDLES"'
        contains "$init" 'perch_state_commit "$UNION"'
        persistence_line=$(grep -nF 'persistent_changes "$DATA" "$CHANGES"' "$init" | cut -d: -f1)
        union_line=$(grep -nF 'init_union "$CHANGES" "$UNION" "$BUNDLES"' "$init" | cut -d: -f1)
        append_line=$(grep -nF 'union_append_bundles "$BUNDLES" "$UNION"' "$init" | cut -d: -f1)
        inventory_line=$(grep -nF 'publish_union_branch_inventory "$CHANGES" "$BUNDLES"' "$init" | cut -d: -f1)
        normalize_line=$(grep -nF 'normalize_module_whiteouts "$UNION"' "$init" | cut -d: -f1)
        commit_line=$(grep -nF 'perch_state_commit "$UNION"' "$init" | cut -d: -f1)
        [ "$persistence_line" -lt "$union_line" ]
        [ "$union_line" -lt "$append_line" ]
        [ "$append_line" -lt "$inventory_line" ]
        [ "$inventory_line" -lt "$normalize_line" ]
        [ "$normalize_line" -lt "$commit_line" ]
    done
}

@test "boot menus route interactive session creation through setup" {
    minioslib="$ROOT/../minioslib"
    lib="$ROOT/livekit-mos/lib/livekitlib"

    [ "$(grep -Fc 'perchdir=setup' "$minioslib")" -eq 3 ]
    ! grep -Fq 'perchdir=new' "$minioslib"
    contains "$lib" 'select_new_session_mode()'
    contains "$lib" 'if [ "$ACTION" = "ask" ] && [ -z "$LASTSESSION" ]; then'
    contains "$lib" 'ACTION="setup"'
    contains "$lib" "printf '%s\\n' 'DynBlk'"
    contains "$lib" "printf '%s\\n' 'LUKS2'"
    contains "$lib" "ncurses-menu -t 'Encryption:'"
}

@test "LiveKit and Dracut preserve runtime state at the consumer path" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    contains "$lib" 'perch_state_stage_livekit'
    contains "$lib" 'perch_state_preserve "$UNION"'
    contains "$lib" 'run/initramfs/minios-persistence'
    contains "$lib" 'local INVENTORY="${3:-/minios-aufs-branches}"'
    contains "$lib" 'install_aufs_runtime_inventory .'
    [ "$(grep -Fc 'perch_state_preserve "$UNION"' "$lib")" -eq 2 ]
    [ "$(grep -Fc 'install_aufs_runtime_inventory .' "$lib")" -eq 3 ]
}

@test "LiveKit and Dracut preserve initrd output and mirror requested consoles" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    boot="$ROOT/livekit-mos/bin/minios-boot"
    contains "$lib" 'console=tty0'
    contains "$lib" 'console=ttyS0,'
    contains "$lib" 'MINIOS_INITRD_LOG:-/var/log/initrd.log'
    contains "$lib" 'tee "$BOOT_CONSOLE_LOG" "$TTY0" "$TTYS0"'
    contains "$lib" 'run/initramfs/var/log/initrd.log'
    contains "$lib" 'wait "$BOOT_CONSOLE_MIRROR_PID"'
    contains "$boot" 'executed there in a chroot before switch_root'
    contains "$boot" 'tee <"$LOG_PIPE" /var/log/minios/minios-boot.log 2>/dev/null &'
    contains "$boot" 'cat <"$LOG_PIPE" 2>/dev/null &'
    contains "$boot" 'rm -f "$LOG_PIPE"'
    contains "$boot" 'minios-boot failed with status $STATUS'
    ! contains "$boot" 'minios-boot started at'
    ! contains "$boot" 'minios-boot finished with status'
    contains "$boot" 'set_autologin()'
    contains "$boot" 'return 0'
    contains "$boot" 'wait "$LOG_PID" 2>/dev/null || true'
    contains "$boot" "trap 'stop_log' EXIT"
    contains "$boot" 'stop_log'
    ! contains "$boot" '>/dev/console'
    for init in "$ROOT/livekit-mos/init" "$ROOT/dracut-mos/90minios/minios-init"; do
        contains "$init" boot_console_mirror_start
        contains "$init" boot_console_mirror_stop
        start_line=$(grep -nF boot_console_mirror_start "$init" | cut -d: -f1)
        minios_boot_line=$(grep -nF 'minios_boot "$DATA" "$UNION"' "$init" | cut -d: -f1)
        stop_line=$(grep -nF boot_console_mirror_stop "$init" | cut -d: -f1)
        [ "$start_line" -lt "$minios_boot_line" ]
        [ "$minios_boot_line" -lt "$stop_line" ]
    done
}

@test "console mirroring does not collide with LUKS prompt descriptors" {
    run env \
        MINIOS_BOOT_CMDLINE='console=tty0 console=ttyS0,115200n8' \
        MINIOS_CONSOLE_TTY0=/dev/null \
        MINIOS_CONSOLE_TTYS0=/dev/null \
        MINIOS_CONSOLE_FIFO="$WORK/console.fifo" \
        MINIOS_INITRD_LOG="$WORK/initrd.log" \
        bash -c '
            source "$1"
            boot_console_mirror_start
            echo initrd-log-marker
            exec 3<>/dev/null
            exec 3>&-
            boot_console_mirror_stop
            echo mirror-stopped
            test ! -e "$MINIOS_CONSOLE_FIFO"
            grep -q initrd-log-marker "$MINIOS_INITRD_LOG"
        ' _ "$ROOT/livekit-mos/lib/livekitlib"
    [ "$status" -eq 0 ]
    [[ "$output" == *mirror-stopped* ]]
}

@test "initrd output is logged without serial console parameters" {
    run env \
        MINIOS_BOOT_CMDLINE='quiet splash' \
        MINIOS_CONSOLE_FIFO="$WORK/console.fifo" \
        MINIOS_INITRD_LOG="$WORK/initrd.log" \
        bash -c '
            source "$1"
            boot_console_mirror_start
            echo file-only-initrd-marker
            boot_console_mirror_stop
            grep -q file-only-initrd-marker "$MINIOS_INITRD_LOG"
        ' _ "$ROOT/livekit-mos/lib/livekitlib"
    [ "$status" -eq 0 ]
    [[ "$output" == *file-only-initrd-marker* ]]
}

@test "Dracut finalizes initrd log into the preserved initramfs tree" {
    run env \
        MINIOS_BOOT_CMDLINE='quiet splash' \
        MINIOS_CONSOLE_FIFO="$WORK/console.fifo" \
        MINIOS_INITRD_LOG="$WORK/initrd.log" \
        TARGET_ROOT="$WORK/root" \
        bash -c '
            source "$1"
            mkdir -p "$TARGET_ROOT/run/initramfs/var/log"
            boot_console_mirror_start
            echo dracut-final-marker
            boot_console_mirror_stop "$TARGET_ROOT"
            grep -q dracut-final-marker "$TARGET_ROOT/run/initramfs/var/log/initrd.log"
        ' _ "$ROOT/livekit-mos/lib/livekitlib"
    [ "$status" -eq 0 ]
}

@test "root union failure stops boot while AUFS append failure remains best effort" {
    for init in "$ROOT/livekit-mos/init" "$ROOT/dracut-mos/90minios/minios-init"; do
        contains "$init" 'persistent_changes "$DATA" "$CHANGES"'
        ! grep -Fq 'persistent_changes "$DATA" "$CHANGES" ||' "$init"
        contains "$init" 'fatal "Cannot construct the root union"'
        ! contains "$init" 'fatal "Cannot complete the root union"'
        contains "$init" 'perch_state_abort "Cannot complete the root union; continuing with available bundles."'
    done
    ! contains "$ROOT/livekit-mos/lib/livekitlib" 'fatal_stop()'
    contains "$ROOT/livekit-mos/lib/livekitlib" \
        'mount -t aufs -o "xino=/.xino,br:$1=rw" aufs "$2"'
    contains "$ROOT/livekit-mos/lib/livekitlib" \
        'mount -t aufs -o xino="/.xino",trunc_xino,br="$1" aufs "$2"'
}

@test "Dracut activates MiniOS live root only for boot=live" {
    for hook in "$ROOT/dracut-mos/90minios/parse-minios.sh" "$ROOT/dracut-mos/90minios/minios-mount-root.sh"; do
        contains "$hook" 'getarg boot=live'
        ! contains "$hook" 'getarg from='
    done
}

@test "fstab creation detects union while retaining the systemd mount layout" {
    source "$ROOT/livekit-mos/lib/livekitlib"
    debug_log() { :; }
    get_union_fs() { echo overlayfs; }

    systemd_root="$WORK/systemd-root"
    mkdir -p "$WORK/data" "$systemd_root/etc" "$systemd_root/sbin"
    ln -s /usr/lib/systemd/systemd "$systemd_root/sbin/init"
    fstab_create "$systemd_root" "$WORK/data"
    [ "$(sed -n '1p' "$systemd_root/etc/fstab")" = 'overlay / overlay defaults 0 0' ]
    contains "$systemd_root/etc/fstab" 'tmpfs /dev/shm tmpfs defaults 0 0'
    [ ! -e "$systemd_root/var/log/fsck/checkfs" ]

    sysv_root="$WORK/sysv-root"
    mkdir -p "$sysv_root/etc" "$sysv_root/sbin"
    ln -s /sbin/init "$sysv_root/sbin/init"
    fstab_create "$sysv_root" "$WORK/data"
    [ "$(sed -n '1p' "$sysv_root/etc/fstab")" = 'overlay / overlay defaults 0 0' ]
    ! contains "$sysv_root/etc/fstab" 'tmpfs /dev/shm tmpfs defaults 0 0'
    [ -d "$sysv_root/run/shm" ]
    [ -f "$sysv_root/var/log/fsck/checkfs" ]
    [ -f "$sysv_root/var/log/fsck/checkroot" ]
}

@test "data discovery probes read-only before enabling writes on the selected source" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    source "$lib"

    [ "$(fs_options ext4 ro)" = '-t ext4 -o ro' ]
    [ "$(fs_options ext4)" = '-t ext4 -o rw' ]

    body=$(awk '/^find_data_try\(\)/,/^}/' "$lib")
    [[ "$body" == *'OPTIONS="$(fs_options "$FS" ro)"'* ]]
    [ "$(printf '%s\n' "$body" | grep -Fc 'data_mount_make_writable "$DRIVE" "$1" "$FS" || true')" -eq 2 ]
}

@test "selected data source falls back to a clean writable mount" {
    source "$ROOT/livekit-mos/lib/livekitlib"
    debug_log() { :; }
    log="$WORK/remount.log"
    mount() {
        printf 'mount %s\n' "$*" >>"$log"
        [ "$1" != -o ]
    }
    umount() {
        printf 'umount %s\n' "$*" >>"$log"
        return 0
    }

    data_mount_make_writable /dev/test "$WORK/data" ext4

    contains "$log" 'mount -o remount,rw'
    contains "$log" "umount $WORK/data"
    contains "$log" "mount /dev/test $WORK/data -t ext4 -o rw"
}

@test "read-only selected data source is restored if writable mounting is impossible" {
    source "$ROOT/livekit-mos/lib/livekitlib"
    debug_log() { :; }
    log="$WORK/remount-ro.log"
    mount() {
        printf 'mount %s\n' "$*" >>"$log"
        return 1
    }
    umount() {
        printf 'umount %s\n' "$*" >>"$log"
        return 0
    }

    run data_mount_make_writable /dev/test "$WORK/data" ext4

    [ "$status" -ne 0 ]
    contains "$log" "mount /dev/test $WORK/data -t ext4 -o rw"
    contains "$log" "mount /dev/test $WORK/data -t ext4 -o ro"
}

@test "change_root detects union before unmounting proc for systemd" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    body=$(awk '/^change_root\(\)/,/^}/' "$lib")

    [[ "$body" == *'if echo "$INIT_TARGET" | grep -q systemd; then'* ]]
    [[ "$body" == *'umount /proc'* ]]
    [[ "$body" == *'mount -n -o remount,ro aufs .'* ]]
    [ "$(printf '%s\n' "$body" | grep -c 'UNION_TYPE=$(get_union_fs)')" -eq 1 ]
    union_line=$(printf '%s\n' "$body" | grep -n 'UNION_TYPE=$(get_union_fs)' | cut -d: -f1)
    unmount_line=$(printf '%s\n' "$body" | grep -n 'umount /proc' | cut -d: -f1)
    [ "$union_line" -lt "$unmount_line" ]
}

@test "both initrd builders include the aufs-ng DKMS module" {
    contains "$ROOT/dracut-mos/mkdracut" 'OPTIONAL_DRIVERS="aufs aufs-ng ntfs ntfs3 exfat"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" \
        'instmods squashfs overlay loop zram aufs aufs-ng'
    contains "$ROOT/livekit-mos/mkinitrfs" \
        'copy_including_deps "/$LMK/updates/dkms/aufs-ng."*'
}


@test "runtime-state staging failure is nonfatal" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    body=$(awk '/^change_root\(\)/,/^}/' "$lib")
    [[ "$body" == *'perch_state_stage_livekit || {'* ]]
    [[ "$body" == *'session saving will be unavailable'* ]]
    [[ "$body" != *fatal_stop* ]]
}

@test "metadata replacement has no write-only bak copy" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    ! grep -Fq '.bak.tmp' "$lib"
    ! grep -Fq '${CONF}.bak' "$lib"
}

@test "successful persistence activation refreshes session directory mtime" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    [ "$(grep -Fc 'touch "$CHANDIR/$PERCHDIR" 2>/dev/null || true' "$lib")" -eq 2 ]
}

@test "all shutdown implementations retain legacy loop detachment" {
    for shutdown in "$ROOT/livekit-mos/shutdown" "$ROOT/dracut-mos/90minios/minios-shutdown.sh"; do
        contains "$shutdown" close_owned_crypt
        contains "$shutdown" 'detach_free_loops()'
        contains "$shutdown" 'losetup -a | cut -d : -f 1'
        contains "$shutdown" 'losetup -d "$LOOP" 2>/dev/null'
    done
    ! grep -Fq '. /lib/livekitlib' "$ROOT/dracut-mos/90minios/minios-shutdown.sh"
}

@test "shutdown implementations publish clean persistence state before data unmount" {
    livekit="$ROOT/livekit-mos/shutdown"
    dracut="$ROOT/dracut-mos/90minios/minios-shutdown.sh"
    contains "$livekit" 'umount_all /memory/changes'
    contains "$livekit" 'session_conf_mark_clean'
    contains "$dracut" 'mark_persistence_session_clean'
    contains "$dracut" 'umount_all /run/initramfs/memory/changes'
    for shutdown in "$livekit" "$dracut"; do
        contains "$shutdown" 'detach_shutdown_encryption()'
        contains "$shutdown" 'cryptsetup close "$SHUTDOWN_CRYPT_MAPPER"'
        contains "$shutdown" 'losetup -d "$SHUTDOWN_LOOP_DEVICE"'
        contains "$shutdown" 'losetup -a 2>/dev/null | grep -q "^$SHUTDOWN_LOOP_DEVICE:"'
        contains "$shutdown" '[ "$LOOP" = "${SHUTDOWN_LOOP_DEVICE:-none}" ]'
        contains "$shutdown" '[ -e "/dev/mapper/${SHUTDOWN_CRYPT_MAPPER:-none}" ]'
        top_line=$(grep -nF 'umount_changes_top || ENCRYPTION_DETACH_FAILED=1' "$shutdown" | cut -d: -f1)
        crypt_line=$(grep -nF 'detach_shutdown_encryption || ENCRYPTION_DETACH_FAILED=1' "$shutdown" | cut -d: -f1)
        lower_line=$(grep -nF 'umount_all /memory/changes' "$shutdown" | tail -n1 | cut -d: -f1)
        [ "$top_line" -lt "$crypt_line" ]
        [ "$crypt_line" -lt "$lower_line" ]
    done
}

@test "shutdown detaches boot dynblk and drains secondary devices before the backing store" {
    for shutdown in "$ROOT/livekit-mos/shutdown" "$ROOT/dracut-mos/90minios/minios-shutdown.sh"; do
        contains "$shutdown" 'detach_dynblk_device()'
        contains "$shutdown" 'detach_shutdown_dynblk()'
        contains "$shutdown" 'drain_remaining_dynblk()'
        contains "$shutdown" 'SHUTDOWN_DYNBLK_DEVICE=$(sed -n '\''s/^dynblk_device=//p'\'' "$BOOT_STATE" | tail -n 1)'
        contains "$shutdown" 'for SYS in /sys/block/dynblk[0-9]*; do'
        contains "$shutdown" 'dynblk unload "$DEVICE" --execute'
        contains "$shutdown" 'detach_shutdown_dynblk || DYNBLK_DETACH_FAILED=1'
        contains "$shutdown" 'drain_remaining_dynblk || DYNBLK_DRAIN_FAILED=1'
        contains "$shutdown" '[ "$DYNBLK_DRAIN_FAILED" -eq 0 ]'
        changes_line=$(grep -nF 'umount_all /memory/changes' "$shutdown" | tail -n1 | cut -d: -f1)
        detach_line=$(grep -nF 'detach_shutdown_dynblk || DYNBLK_DETACH_FAILED=1' "$shutdown" | cut -d: -f1)
        drain_line=$(grep -nF 'drain_remaining_dynblk || DYNBLK_DRAIN_FAILED=1' "$shutdown" | cut -d: -f1)
        memory_line=$(grep -nF 'umount_all /memory' "$shutdown" | tail -n1 | cut -d: -f1)
        [ "$changes_line" -lt "$detach_line" ]
        [ "$detach_line" -lt "$drain_line" ]
        [ "$drain_line" -lt "$memory_line" ]
    done
}

@test "shutdown verifies pre-unmount SquashFS save before teardown" {
    for shutdown in "$ROOT/livekit-mos/shutdown" "$ROOT/dracut-mos/90minios/minios-shutdown.sh"; do
        contains "$shutdown" 'verify_shutdown_squashfs_save || SQUASHFS_SAVE_FAILED=1'
        contains "$shutdown" '/minios-persistence/boot-state'
        contains "$shutdown" '/memory/data/minios/changes/session.conf'
        contains "$shutdown" '/minios-persistence/shutdown-save-complete'
        contains "$shutdown" 'SQUASHFS_METADATA_FINALIZED=1'
        contains "$shutdown" 'SQUASHFS_METADATA_FINALIZED=0'
        ! contains "$shutdown" 'minios-session save'
        verify_line=$(grep -nF 'verify_shutdown_squashfs_save || SQUASHFS_SAVE_FAILED=1' "$shutdown" | cut -d: -f1)
        if grep -Fq 'debug_log "- Detaching loops"' "$shutdown"; then
            detach_line=$(grep -nF 'debug_log "- Detaching loops"' "$shutdown" | cut -d: -f1)
        else
            detach_line=$(grep -nF 'Detaching loop devices...' "$shutdown" | cut -d: -f1)
        fi
        union_line=$(grep -nF 'umount_all /oldroot' "$shutdown" | head -n1 | cut -d: -f1)
        [ "$verify_line" -lt "$detach_line" ]
        [ "$verify_line" -lt "$union_line" ]
    done
}

@test "builders declare crypto and default conf-only metadata payloads" {
    for builder in "$ROOT/livekit-mos/mkinitrfs" "$ROOT/dracut-mos/mkdracut"; do
        contains "$builder" --crypt
        contains "$builder" 'dm-crypt support'
    done
    contains "$ROOT/livekit-mos/mkinitrfs" minios-initramfs-crypt
    ! contains "$ROOT/livekit-mos/mkinitrfs" 'bin/jq'
    contains "$ROOT/livekit-mos/mkinitrfs" 'bin/unsquashfs'
    module="$ROOT/dracut-mos/90minios/module-setup.sh"
    contains "$module" install_bundled_crypt
    contains "$module" 'inst_multiple cryptsetup'
    contains "$module" minios-initramfs-crypt
    ! contains "$module" 'inst_simple "$STATIC_BIN/jq" "/bin/jq"'
    contains "$module" 'inst_simple "$STATIC_BIN/unsquashfs" "/bin/unsquashfs"'
    [ -x "$ROOT/livekit-mos/usr/sbin/cryptsetup" ]
}

@test "Dracut compression follows the target kernel decoder configuration" {
    builder="$ROOT/dracut-mos/mkdracut"
    contains "$builder" 'CONFIG_RD_ZSTD=y'
    contains "$builder" 'CONFIG_RD_GZIP=y'
    contains "$builder" 'CONFIG_RD_XZ=y'
    contains "$builder" '--compress "$COMPRESSION"'
    contains "$builder" 'command -v zstd'
    contains "$builder" 'command -v gzip'
    contains "$builder" 'command -v xz'
    ! contains "$ROOT/dracut-mos/90-minios.conf" 'compress="zstd"'
}

@test "Dracut handles built-in CRC32C and adds dm-crypt explicitly" {
    contains "$ROOT/dracut-mos/mkdracut" 'CONFIG_CRYPTO_CRC32C=y'
    contains "$ROOT/dracut-mos/mkdracut" 'mktemp -d /tmp/minios-dracut.XXXXXX'
    contains "$ROOT/dracut-mos/mkdracut" 'export dracutbasedir="$DRACUT_BASE"'
    contains "$ROOT/dracut-mos/mkdracut" 'exec "${0}.minios-real"'
    contains "$ROOT/dracut-mos/mkdracut" '[ "$arg" = "crc32c" ] || args+=("$arg")'
    contains "$ROOT/dracut-mos/mkdracut" 'AVAILABLE_DRIVERS="$AVAILABLE_DRIVERS dm-crypt"'
    ! contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'instmods crc32c '
}

@test "Dracut explicitly carries optical SATA and cloud network drivers" {
    builder="$ROOT/dracut-mos/mkdracut"
    contains "$builder" 'vfat isofs ahci'
    contains "$builder" 'virtio_pci virtio_net'
    contains "$builder" 'if [ "$CLOUD" = "true" ]'
}

@test "dynblk weak-RAM mapping budget follows compact 128-block runtime chunks" {
    lib="$ROOT/livekit-mos/lib/livekitlib"
    contains "$lib" 'NORMALIZED_MB=$((((MEM_TOTAL_MB + 63) / 64) * 64))'
    contains "$lib" 'BUDGET=$((NORMALIZED_MB / 4))'
    contains "$lib" '[ "$BUDGET" -gt 4096 ] && BUDGET=4096'
    contains "$lib" 'DYNBLK_FULL_MAP_MB=$((DYNBLK_MAP_MEMORY_MB * 128))'
    contains "$lib" 'REQUIRED_MAP_MB=$(((PERCHSIZE + 127) / 128))'
    contains "$lib" 'dynblk_map_budget_mb()'
    run grep -F 'BACKEND_BUDGET - 192' "$lib"
    [ "$status" -ne 0 ]
}

@test "builders keep dynfilefs while coupling dynblk CLI to the kernel module" {
    contains "$ROOT/livekit-mos/mkinitrfs" 'bin/dynfilefs'
    contains "$ROOT/livekit-mos/mkinitrfs" 'copy_files "$INITRAMFS" bin/dynblk'
    contains "$ROOT/livekit-mos/mkinitrfs" 'ln -s dynfilefs "$INITRAMFS/bin/@mount.dynfilefs"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'inst_simple "$STATIC_BIN/dynfilefs" "/bin/dynfilefs"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'inst_simple "$dynblk_bin" "/bin/dynblk"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'ln -sf dynfilefs "${initdir}/bin/@mount.dynfilefs"'

    run "$ROOT/livekit-mos/bin/dynfilefs"
    [ "$status" -eq 1 ]
    [[ "$output" == *'dynfilefs 4.5.1'* ]]
    run "$ROOT/livekit-mos/bin/dynblk" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *'dynblk create PATH'* ]]
}

@test "initrd restores SquashFS sessions without carrying mksquashfs" {
    ! contains "$ROOT/livekit-mos/mkinitrfs" 'bin/mksquashfs'
    ! contains "$ROOT/dracut-mos/90minios/module-setup.sh" '"/bin/mksquashfs"'
    contains "$ROOT/livekit-mos/mkinitrfs" 'bin/unsquashfs'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" '"/bin/unsquashfs"'
}

@test "crypto payload copy list is complete and its symlinks are valid" {
    cd "$ROOT/livekit-mos"
    while IFS= read -r path; do
        [ -e "$path" ] || [ -L "$path" ]
    done <"$ROOT/buildroot/crypt_payload_files.txt"
    [ "$(readlink lib/ld-musl-i386.so.1)" = libc.so ]
    [ "$(readlink lib/libblkid.so.1)" = libblkid.so.1.1.0 ]
    [ "$(readlink lib/libsmartcols.so.1)" = libsmartcols.so.1.1.0 ]
    [ "$(readlink lib/libuuid.so.1)" = libuuid.so.1.3.0 ]
    [ "$(readlink usr/lib/libcryptsetup.so.12)" = libcryptsetup.so.12.11.0 ]
    [ "$(readlink usr/lib/libjson-c.so.5)" = libjson-c.so.5.4.0 ]
    [ "$(readlink usr/lib/libpopt.so.0)" = libpopt.so.0.0.2 ]
}

@test "both builders use the crypto payload copy list" {
    contains "$ROOT/livekit-mos/mkinitrfs" 'crypt_payload_files.txt'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'crypt_payload_files.txt'
}

@test "layered LUKS contracts retain Raw sizing and existing FAT limit" {
    LIB="$ROOT/livekit-mos/lib/livekitlib"
    contains "$LIB" 'PERCHFILE="$PERCHDIR/changes.img"'
    contains "$LIB" 'session_encryption[$SESSION]=luks'
    contains "$LIB" 'luks_attach_loop "$CHANDIR/$PERCHFILE"'
    contains "$LIB" 'TARGET_BYTES=$((PERCHSIZE * 1048576))'
    contains "$LIB" 'truncate -s "${PERCHSIZE}M" "$CHANDIR/$PERCHFILE"'
    contains "$LIB" 'if [ "$FS_TYPE" = "vfat" ] && [ "$PERCHSIZE" -gt 4000 ]; then'
    ! grep -Fq 'PERCHMODE="luks"' "$LIB"
}

exercise_module_payload() (
    source "$ROOT/dracut-mos/90minios/module-setup.sh"
    initdir="$WORK/module-$1"
    moddir="$ROOT/dracut-mos/90minios"
    STATIC_BIN=/unused
    LIVEKITLIB=/unused
    TERMINFO=/unused
    DRACUT_MOS="$ROOT/dracut-mos"
    mkdir -p "$initdir/etc"
    inst_hook() { :; }
    inst_script() { :; }
    inst_simple() { :; }
    inst_dir() { :; }
    MODULE_FAIL=$1
    inst_multiple() { return "$MODULE_FAIL"; }
    MINIOS_CRYPT=true
    if [ "$MODULE_FAIL" -eq 0 ]; then
        install >/dev/null 2>&1 || true
        [ -f "$initdir/etc/minios-initramfs-crypt" ]
    else
        ! install >/dev/null 2>&1
        [ ! -e "$initdir/etc/minios-initramfs-crypt" ]
    fi
)

@test "in-tree Dracut module creates its marker and propagates payload failure" {
    run exercise_module_payload 0
    [ "$status" -eq 0 ]
    run exercise_module_payload 1
    [ "$status" -eq 0 ]
}

@test "bundled crypto payload copies with a complete runnable closure" {
    source "$ROOT/dracut-mos/90minios/module-setup.sh"
    initdir="$WORK/bundled-crypt"
    mkdir -p "$initdir"

    install_bundled_crypt "$ROOT/livekit-mos"

    [ -L "$initdir/lib/ld-musl-i386.so.1" ]
    [ -x "$initdir/usr/sbin/cryptsetup" ]
    run "$initdir/lib/libc.so" \
        --library-path "$initdir/lib:$initdir/usr/lib" \
        "$initdir/usr/sbin/cryptsetup" --version
    [ "$status" -eq 0 ]
    [[ "$output" == cryptsetup\ 2.8.4* ]]
}
