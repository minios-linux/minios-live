#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    PROGRAM="$ROOT/livekit-mos/bin/dynblk"
    BUSYBOX="$ROOT/livekit-mos/bin/busybox"
}

@test "dynblk initramfs program is static i686 without glibc dependencies" {
    [ -x "$PROGRAM" ]
    run file "$PROGRAM"
    [ "$status" -eq 0 ]
    [[ "$output" == *'ELF 32-bit'* ]]
    [[ "$output" == *'Intel i386'* ]]
    [[ "$output" == *'statically linked'* ]]
    run readelf -d "$PROGRAM"
    [ "$status" -eq 0 ]
    [[ "$output" != *'(NEEDED)'* ]]
    run sh -c 'strings "$1" | grep -q "GLIBC_"' sh "$PROGRAM"
    [ "$status" -ne 0 ]
}

@test "dynblk initramfs program exposes device-only management" {
    run "$PROGRAM" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *'dynblk create PATH'* ]]
    [[ "$output" == *'dynblk check PATH'* ]]
    [[ "$output" == *'no mkfs, mount, fsck or filesystem resize'* ]]
}

@test "dynblk dry-run needs neither a block device nor codec tools" {
    run "$PROGRAM" grow /dev/dynblk0 32GiB
    [ "$status" -eq 0 ]
    [[ "$output" == *'no filesystem resize'* ]]
    run "$PROGRAM" unload /dev/dynblk17
    [ "$status" -eq 0 ]
    [[ "$output" == *'DYNBLK_DETACH /dev/dynblk17'* ]]
    [ ! -e /var/lib/volume000.db ]
    run "$PROGRAM" create /var/lib/volume000.db --compression 842
    [ "$status" -eq 0 ]
    [[ "$output" == *'algorithm=842'* ]]
    [ ! -e /var/lib/volume000.db ]
}

@test "bundled BusyBox supplies module management applets" {
    for applet in modprobe insmod rmmod; do
        run "$BUSYBOX" --list
        [ "$status" -eq 0 ]
        echo "$output" | grep -Fxq "$applet"
    done
    run "$BUSYBOX" modprobe --help
    [ "$status" -eq 0 ]
    [[ "$output" == *'MODULE [SYMBOL=VALUE]'* ]]
}

@test "both initramfs builders install dynblk CLI only when dynblk.ko is present" {
    ! grep -Fqx '    bin/dynblk' "$ROOT/livekit-mos/mkinitrfs"
    grep -Fq 'copy_files "$INITRAMFS" bin/dynblk' "$ROOT/livekit-mos/mkinitrfs"
    ! grep -Fq 'bin/dynblk-init' "$ROOT/livekit-mos/mkinitrfs"
    ! grep -Fq 'inst_simple "$STATIC_BIN/dynblk" "/bin/dynblk"' \
        "$ROOT/dracut-mos/90minios/module-setup.sh"
    grep -Fq 'inst_simple "$dynblk_bin" "/bin/dynblk"' \
        "$ROOT/dracut-mos/90minios/module-setup.sh"
    ! grep -Fq 'dynblk-init' "$ROOT/dracut-mos/90minios/module-setup.sh"
    grep -Fq 'ln -s dynfilefs "$INITRAMFS/bin/@mount.dynfilefs"' \
        "$ROOT/livekit-mos/mkinitrfs"
    grep -Fq 'ln -sf dynfilefs "${initdir}/bin/@mount.dynfilefs"' \
        "$ROOT/dracut-mos/90minios/module-setup.sh"
}

@test "livekit keeps dynblk module plain before depmod" {
    grep -Fq 'normalize_dynblk_module' "$ROOT/livekit-mos/mkinitrfs"
    grep -Fq '! -path "*/updates/dkms/dynblk.ko"' "$ROOT/livekit-mos/mkinitrfs"
    grep -Fq 'normalize_dynblk_module || return 1' \
        "$ROOT/dracut-mos/90minios/module-setup.sh"
    grep -Fq 'minios-initramfs-dynblk' "$ROOT/livekit-mos/mkinitrfs"
    grep -Fq 'minios-initramfs-dynblk' "$ROOT/dracut-mos/90minios/module-setup.sh"
}

@test "dynblk initramfs integration has no Python or kmod runtime payload" {
    ! grep -Eq 'python|/usr/bin/kmod' "$ROOT/livekit-mos/mkinitrfs"
    [ ! -e "$ROOT/livekit-mos/bin/dynblk-init" ]
}
