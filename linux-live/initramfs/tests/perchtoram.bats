#!/usr/bin/env bats

setup() {
    WORK=$(mktemp -d)
    export MINIOS_CMDLINE_FILE="$WORK/cmdline"
    export MINIOS_PROC_MEMINFO="$WORK/meminfo"
    export MINIOS_PERSISTENCE_RUNDIR="$WORK/state"
    : >"$MINIOS_CMDLINE_FILE"
    printf 'MemAvailable: 1048576 kB\n' >"$MINIOS_PROC_MEMINFO"
    . "$BATS_TEST_DIRNAME/../livekit-mos/lib/livekitlib"
    debug_log() { :; }
    prepare_perch_ram() { :; }
    boot_warning_notify() { printf '%s\n' "$*" >>"$WORK/warnings"; }
    mkdir -p "$WORK/store/1" "$WORK/store/2" "$WORK/store/3"
    printf 'raw-one' >"$WORK/store/1/changes.img"
    printf 'raw-two' >"$WORK/store/2/changes.img"
    printf 'native-data' >"$WORK/store/3/user-file"
    printf 'default=1\nrunning=1\nsession_mode[1]=raw\nsession_mode[2]=raw\nsession_mode[3]=native\nsession_encryption[2]=luks\n' >"$WORK/store/session.conf"
}

teardown() {
    rm -rf "$WORK"
}

@test "persistence RAM defaults depend only on the system RAM token" {
    for cmdline in 'perch' 'perchtoram=full' 'toram'; do
        printf '%s\n' "$cmdline" >"$MINIOS_CMDLINE_FILE"
        [ "$(perchtoram_mode)" = off ]
    done
    for cmdline in 'perch toram' 'perchdir=resume toram=full' 'perch toram=trim'; do
        printf '%s\n' "$cmdline" >"$MINIOS_CMDLINE_FILE"
        [ "$(perchtoram_mode)" = trim ]
    done
    printf 'perch perchtoram=full\n' >"$MINIOS_CMDLINE_FILE"
    [ "$(perchtoram_mode)" = full ]
    [ -z "$(toram_mode)" ]
}

@test "last persistence RAM value wins and invalid values warn" {
    printf 'perch toram perchtoram=trim perchtoram=off\n' >"$MINIOS_CMDLINE_FILE"
    [ "$(perchtoram_mode)" = off ]
    printf 'perch perchtoram=typo\n' >"$MINIOS_CMDLINE_FILE"
    [ "$(perchtoram_mode)" = off ]
    grep -q 'Invalid perchtoram' "$WORK/warnings"
}

@test "trim copies only the selected container and its metadata" {
    copy_perch_to_ram "$WORK/store" "$WORK/ram" 2 trim raw
    cmp "$WORK/store/2/changes.img" "$WORK/ram/2/changes.img"
    [ ! -e "$WORK/ram/1" ]
    [ ! -e "$WORK/ram/3" ]
    grep -Fxq 'default=2' "$WORK/ram/session.conf"
    grep -Fxq 'session_encryption[2]=luks' "$WORK/ram/session.conf"
    ! grep -q 'session_mode\[1\]\|session_mode\[3\]\|running=' "$WORK/ram/session.conf"
    grep -Fxq 'default=1' "$WORK/store/session.conf"
}

@test "full copies supported containers and excludes native data and metadata" {
    copy_perch_to_ram "$WORK/store" "$WORK/ram" 1 full raw
    [ -f "$WORK/ram/1/changes.img" ]
    [ -f "$WORK/ram/2/changes.img" ]
    [ ! -e "$WORK/ram/3" ]
    ! grep -q 'session_mode\[3\]' "$WORK/ram/session.conf"
}

@test "native selection does not copy its tree" {
    copy_perch_to_ram "$WORK/store" "$WORK/ram" 3 trim native
    [ ! -e "$WORK/ram/3" ]
    [ ! -s "$WORK/ram/session.conf" ]
    [ -f "$WORK/store/3/user-file" ]
}

@test "insufficient memory fails before copying container data" {
    printf 'MemAvailable: 1024 kB\n' >"$MINIOS_PROC_MEMINFO"
    run copy_perch_to_ram "$WORK/store" "$WORK/ram" 1 trim raw
    [ "$status" -ne 0 ]
    [ ! -e "$WORK/ram/1" ]
    [ -f "$WORK/store/1/changes.img" ]
}

@test "a container symlink cannot retain a disk dependency in RAM" {
    ln -s "$WORK/store/1/changes.img" "$WORK/store/2/link.img"
    run copy_perch_to_ram "$WORK/store" "$WORK/ram" 2 trim raw
    [ "$status" -ne 0 ]
    [ ! -e "$WORK/ram/2" ]
}

@test "a device-qualified store preserves an explicit session number" {
    printf 'default=2\nsession_mode[1]=raw\nsession_mode[2]=raw\n' >"$WORK/store/session.conf"
    mount_perch_drive() { printf 'minios/changes\n'; }
    session_metadata_select() { printf '%s/session.conf\n' "$1"; }
    get_union_fs() { printf 'overlayfs\n'; }
    run restore_perch_session /dev/test "$WORK/store" /dev/test/minios/changes resume '' false none none 1
    [ "$status" -eq 0 ]
    [ "$output" = '1 raw false none none' ]
}

@test "system tree copying includes dotfiles and never copies sessions" {
    mkdir -p "$WORK/system/changes" "$WORK/target"
    touch "$WORK/system/.config" "$WORK/system/00-core.sb" "$WORK/system/changes/private"
    copy_data "$WORK/system" "$WORK/target"
    [ -f "$WORK/target/.config" ]
    [ -f "$WORK/target/00-core.sb" ]
    [ ! -e "$WORK/target/changes" ]
}

@test "system tree copying reports a failed file copy" {
    mkdir "$WORK/target"
    cp() { return 1; }
    run copy_data "$WORK/store" "$WORK/target"
    [ "$status" -ne 0 ]
}
