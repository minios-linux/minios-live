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
    done
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

@test "all shutdown implementations retain legacy loop detachment with LUKS exclusion" {
    for shutdown in "$ROOT/livekit-mos/shutdown" "$ROOT/dracut-mos/90minios/minios-shutdown.sh"; do
        contains "$shutdown" close_owned_crypt
        contains "$shutdown" 'detach_free_loops()'
        contains "$shutdown" 'losetup -a | cut -d : -f 1'
        contains "$shutdown" '[ -f /run/initramfs/minios-crypt/loop ]'
        contains "$shutdown" '[ "$LOOP" = "$OWNED_LOOP" ] || losetup -d "$LOOP" 2>/dev/null'
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
}

@test "builders and both Dracut modules declare the crypto payload and marker" {
    for builder in "$ROOT/livekit-mos/mkinitrfs" "$ROOT/dracut-mos/mkdracut"; do
        contains "$builder" --crypt
        contains "$builder" 'dm-crypt support'
    done
    contains "$ROOT/livekit-mos/mkinitrfs" minios-initramfs-crypt
    contains "$ROOT/livekit-mos/mkinitrfs" 'bin/jq'
    module="$ROOT/dracut-mos/90minios/module-setup.sh"
    contains "$module" install_bundled_crypt
    contains "$module" 'inst_multiple cryptsetup dmsetup losetup'
    contains "$module" minios-initramfs-crypt
    contains "$module" 'inst_simple "$STATIC_BIN/jq" "/bin/jq"'
    [ -x "$ROOT/livekit-mos/usr/sbin/cryptsetup" ]
    [ -x "$ROOT/livekit-mos/usr/sbin/dmsetup" ]
    [ -x "$ROOT/livekit-mos/sbin/losetup" ]
}

@test "all bundled initrd executables match the payload manifest" {
    manifest="$ROOT/buildroot/initrd_bins.sha256"
    listed=$(awk '{print $2}' "$manifest" | sort)
    actual=$(
        for file in "$ROOT/livekit-mos/bin"/*; do
            [ ! -f "$file" ] || [ ! -x "$file" ] || basename "$file"
        done | sort
    )

    [ "$actual" = "$listed" ]
    cd "$ROOT/livekit-mos/bin"
    sha256sum -c "$manifest"
}

@test "builders install dynblk with the legacy DynFileFS command alias" {
    contains "$ROOT/livekit-mos/mkinitrfs" 'bin/dynblk'
    contains "$ROOT/livekit-mos/mkinitrfs" 'ln -s dynblk "$INITRAMFS/bin/@mount.dynfilefs"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'inst_simple "$STATIC_BIN/dynblk" "/bin/dynblk"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'ln -sf dynblk "${initdir}/bin/@mount.dynfilefs"'

    run "$ROOT/livekit-mos/bin/dynblk"
    [ "$status" -eq 1 ]
    [[ "$output" == *'dynblk 4.5.0'* ]]
}

@test "crypto closure matches its payload manifest" {
    cd "$ROOT/livekit-mos"
    sha256sum -c "$ROOT/buildroot/crypt_payload.sha256"
    [ "$(readlink lib/ld-musl-i386.so.1)" = libc.so ]
    [ "$(readlink lib/libblkid.so.1)" = libblkid.so.1.1.0 ]
    [ "$(readlink lib/libsmartcols.so.1)" = libsmartcols.so.1.1.0 ]
    [ "$(readlink lib/libuuid.so.1)" = libuuid.so.1.3.0 ]
    [ "$(readlink usr/lib/libcryptsetup.so.12)" = libcryptsetup.so.12.11.0 ]
    [ "$(readlink usr/lib/libjson-c.so.5)" = libjson-c.so.5.4.0 ]
    [ "$(readlink usr/lib/libpopt.so.0)" = libpopt.so.0.0.2 ]
}

@test "both builders verify the bundled crypto payload manifest" {
    contains "$ROOT/livekit-mos/mkinitrfs" 'sha256sum -c "$MANIFEST"'
    contains "$ROOT/dracut-mos/90minios/module-setup.sh" 'sha256sum -c "$manifest"'
}

@test "LUKS contracts retain raw sizing and existing FAT limit" {
    LIB="$ROOT/livekit-mos/lib/livekitlib"
    contains "$LIB" 'PERCHFILE="$PERCHDIR/changes.luks"'
    contains "$LIB" 'TARGET_BYTES=$((PERCHSIZE * 1048576))'
    contains "$LIB" 'truncate -s "${PERCHSIZE}M" "$CHANDIR/$PERCHFILE"'
    contains "$LIB" 'if [ "$FS_TYPE" = "vfat" ] && [ "$PERCHSIZE" -gt 4000 ]; then'
    contains "$LIB" 'STATE="${1:-/run/initramfs/minios-crypt}"'
}

@test "Dracut builder rejects crypt mode before attempting a build when cryptsetup is missing" {
    mkdir "$WORK/bin"
    printf '%s\n' '#!/bin/sh' 'exit 0' >"$WORK/bin/dracut"
    chmod +x "$WORK/bin/dracut"
    run env PATH="$WORK/bin" "$ROOT/dracut-mos/mkdracut" --crypt --kernel test-kernel
    [ "$status" -ne 0 ]
    [[ "$output" == *'--crypt requires cryptsetup on the build host'* ]]
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
