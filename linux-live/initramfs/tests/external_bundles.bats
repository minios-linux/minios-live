#!/usr/bin/env bats

setup() {
    LIB="$BATS_TEST_DIRNAME/../livekit-mos/lib/livekitlib"
    WORK=$(mktemp -d)
    export MINIOS_CMDLINE_FILE="$WORK/cmdline"
    export MINIOS_PERCH_ROOT="$WORK/perch"
    export MINIOS_PERCH_ROOT_FILE="$WORK/perch_root"
    export MINIOS_PERCH_STORE_FILE="$WORK/perch_store"
    DATA="$WORK/data/minios"
    BUNDLES="$WORK/bundles"
    LIVEKITNAME=minios
    BEXT=sb
    mkdir -p "$DATA/modules" "$MINIOS_PERCH_ROOT/minios/modules"
    : >"$MINIOS_CMDLINE_FILE"
    printf '%s\n' "$MINIOS_PERCH_ROOT" >"$MINIOS_PERCH_ROOT_FILE"
    . "$LIB"
    debug_log() { :; }
    echo_white_star() { :; }
}

teardown() {
    rm -rf "$WORK"
}

@test "perchtoram does not select system RAM copying" {
    for mode in off trim full; do
        printf 'perch perchtoram=%s\n' "$mode" >"$MINIOS_CMDLINE_FILE"
        [ -z "$(toram_mode)" ]
    done
    printf 'perch toram=full perchtoram=trim\n' >"$MINIOS_CMDLINE_FILE"
    [ "$(toram_mode)" = full ]
    printf 'perchtoram=full toram=trim\n' >"$MINIOS_CMDLINE_FILE"
    [ "$(toram_mode)" = trim ]
}

@test "external system bundle replaces ISO without mounting the old file" {
    touch "$DATA/00-core.sb" "$DATA/01-kernel.sb" "$DATA/modules/app.sb"
    touch "$MINIOS_PERCH_ROOT/minios/00-core.sb"
    touch "$MINIOS_PERCH_ROOT/minios/modules/extra.sb"
    mount() { printf '%s\n' "$*" >>"$WORK/mounts"; }
    mount_bundles "$DATA" "$BUNDLES"
    [ "$(wc -l <"$WORK/mounts")" -eq 4 ]
    grep -Fq "$MINIOS_PERCH_ROOT/minios/00-core.sb" "$WORK/mounts"
    ! grep -Fq "$DATA/00-core.sb" "$WORK/mounts"
    grep -Fq "$DATA/01-kernel.sb" "$WORK/mounts"
    grep -Fq "$MINIOS_PERCH_ROOT/minios/modules/extra.sb" "$WORK/mounts"
}

@test "bundle filters apply equally to external and ISO modules" {
    touch "$DATA/00-core.sb" "$DATA/01-kernel.sb"
    touch "$MINIOS_PERCH_ROOT/minios/00-core.sb" "$MINIOS_PERCH_ROOT/minios/02-app.sb"
    printf 'noload=00\n' >"$MINIOS_CMDLINE_FILE"
    run find_bundles "$DATA" "$MINIOS_PERCH_ROOT/minios"
    [ "$status" -eq 0 ]
    [ "$output" = $'01-kernel.sb\n02-app.sb' ]
}

@test "RAM boot mounts the copied modules rather than reopening the external store" {
    touch "$DATA/00-core.sb" "$MINIOS_PERCH_ROOT/minios/00-core.sb"
    printf 'toram perchtoram=off\n' >"$MINIOS_CMDLINE_FILE"
    mount() { printf '%s\n' "$*" >>"$WORK/mounts"; }
    mount_bundles "$DATA" "$BUNDLES"
    grep -Fq "$DATA/00-core.sb" "$WORK/mounts"
    ! grep -Fq "$MINIOS_PERCH_ROOT/minios/00-core.sb" "$WORK/mounts"
}

@test "session bind mount leaves the partition root accessible" {
    device_bestfs() { printf 'ext4\n'; }
    fs_options() { :; }
    mount_command() { printf 'mount\n'; }
    refresh_devs() { :; }
    mountpoint() { return 1; }
    blkid() { :; }
    mount() { printf '%s\n' "$*" >>"$WORK/mounts"; }
    mount_perch_drive /dev/test "$DATA/changes" /dev/test/minios/changes
    grep -Fxq "/dev/test $MINIOS_PERCH_ROOT" "$WORK/mounts"
    grep -Fxq -- "--bind $MINIOS_PERCH_ROOT/minios/changes $DATA/changes" "$WORK/mounts"
    [ "$(cat "$MINIOS_PERCH_ROOT_FILE")" = "$MINIOS_PERCH_ROOT" ]
}

@test "external replacements are exposed to image tools without activating persistence" {
    touch "$DATA/00-core.sb" "$MINIOS_PERCH_ROOT/minios/00-core.sb"
    touch "$MINIOS_PERCH_ROOT/minios/02-extra.sb"
    mount() { printf '%s\n' "$*" >>"$WORK/mounts"; }
    bind_perch_bundles "$DATA"
    [ "$(wc -l <"$WORK/mounts")" -eq 1 ]
    grep -Fxq -- "--bind $MINIOS_PERCH_ROOT/minios/00-core.sb $DATA/00-core.sb" "$WORK/mounts"
}

@test "RAM data is never rebound to external files" {
    touch "$DATA/00-core.sb" "$MINIOS_PERCH_ROOT/minios/00-core.sb"
    printf 'toram\n' >"$MINIOS_CMDLINE_FILE"
    mount() { return 99; }
    bind_perch_bundles "$DATA"
}

@test "external discovery requests no resizing and preserves the original store" {
    mountpoint() { return 1; }
    mounted_device() { printf '/dev/iso\n'; }
    manage_perch_partition() {
        [ "$3" = ro ] || return 1
        printf '/dev/test/minios/changes\n'
    }
    device_bestfs() { printf 'ext4\n'; }
    fs_options() { printf '%s\n' "$2"; }
    mount_command() { printf 'mount\n'; }
    mount() { printf '%s\n' "$*" >>"$WORK/mounts"; }
    find_perch_data "$DATA"
    grep -Fxq "/dev/test $MINIOS_PERCH_ROOT ro" "$WORK/mounts"
    [ "$(cat "$MINIOS_PERCH_STORE_FILE")" = /dev/test/minios/changes ]
}

@test "a failed bundle mount fails boot preparation" {
    touch "$DATA/00-core.sb"
    mount() { return 1; }
    run mount_bundles "$DATA" "$BUNDLES"
    [ "$status" -ne 0 ]
}

@test "external kernel bundles must match the running kernel" {
    touch "$DATA/00-core.sb" "$DATA/01-kernel-current.sb"
    touch "$MINIOS_PERCH_ROOT/minios/01-kernel-other.sb" "$MINIOS_PERCH_ROOT/minios/01-kernel-current.sb"
    get_running_kernel() { printf 'current\n'; }
    run find_bundles "$DATA" "$MINIOS_PERCH_ROOT/minios"
    [ "$status" -eq 0 ]
    [ "$output" = $'00-core.sb\n01-kernel-current.sb' ]
}

@test "persistence partition selects minios changes rather than the partition root" {
    export MINIOS_VENTOY_DIR="$WORK/no-ventoy"
    blkid() {
        [ "$2" != LABEL=persistence ] || printf '/dev/sda3\n'
    }
    lsblk() { printf 'sda\n'; }
    run manage_perch_partition /dev/sda1 resume ro
    [ "$status" -eq 0 ]
    [ "$output" = /dev/sda3/minios/changes ]
}

@test "module discovery never formats a resizeme partition" {
    export MINIOS_VENTOY_DIR="$WORK/no-ventoy"
    blkid() {
        [ "$2" != LABEL=resizeme ] || printf '/dev/sda3\n'
    }
    lsblk() { printf 'sda\n'; }
    parted() { printf 'unexpected resize\n'; return 1; }
    mke2fs() { printf 'unexpected format\n'; return 1; }
    run manage_perch_partition /dev/sda1 '' ro
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
