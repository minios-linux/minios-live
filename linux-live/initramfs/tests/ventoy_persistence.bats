#!/usr/bin/env bats

setup() {
    LIB="$BATS_TEST_DIRNAME/../livekit-mos/lib/livekitlib"
    WORK=$(mktemp -d)
    export MINIOS_VENTOY_DIR="$WORK/ventoy"
    export MINIOS_VENTOY_PERCH_ROOT="$WORK/backend"
    export MINIOS_PERSISTENCE_RUNDIR="$WORK/state"
    export MINIOS_SYS_CLASS_BLOCK="$WORK/sys"
    export MINIOS_DEV_ROOT="$WORK/dev"
    export MINIOS_CMDLINE_FILE="$WORK/cmdline"
    export MINIOS_BOOT_ID_FILE="$WORK/boot-id"
    export MINIOS_PERCH_ROOT="$WORK/ordinary-store"
    export MINIOS_PERCH_ROOT_FILE="$WORK/perch-root"
    export MINIOS_PERCH_STORE_FILE="$WORK/perch-store"
    CHANGES="$WORK/upper"
    mkdir -p "$MINIOS_VENTOY_DIR" "$CHANGES" "$MINIOS_SYS_CLASS_BLOCK" "$MINIOS_DEV_ROOT"
    : >"$MINIOS_VENTOY_DIR/ventoy_os_param"
    : >"$MINIOS_VENTOY_DIR/ventoy_persistent_map"
    LIVEKITNAME=minios
    printf 'perchdir=resume union=overlayfs\n' >"$MINIOS_CMDLINE_FILE"
    printf '11111111-2222-3333-4444-555555555555\n' >"$MINIOS_BOOT_ID_FILE"
    . "$LIB"
    debug_log() { :; }
    refresh_devs() { :; }
    sleep() { :; }
    boot_warning_notify() { printf '%s\n' "$*" >>"$WORK/warnings"; }
    mount() { printf '%s\n' "$*" >>"$WORK/mounts"; }
    umount() { printf '%s\n' "$*" >>"$WORK/unmounts"; }
    device_bestfs() { printf 'ext4\n'; }
    get_union_fs() { printf 'overlayfs\n'; }
}

teardown() {
    rm -rf "$WORK"
}

@test "a selected but unavailable plugin image ignores every ordinary persistence target" {
    printf 'perchdir=/dev/sda3/minios/changes perchmode=raw\n' >"$MINIOS_CMDLINE_FILE"
    ask_disk() { return 99; }
    blkid() { return 99; }
    restore_perch_session() { return 99; }
    find_perch_data "$WORK/iso/minios"
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ ! -e "$WORK/mounts" ]
    [ ! -e "$MINIOS_PERCH_ROOT_FILE" ]
    [ ! -e "$MINIOS_PERCH_STORE_FILE" ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
    [ -z "$(manage_perch_partition /dev/sda1 resume)" ]
}

@test "ordinary Ventoy uses its data partition without a persistence plugin" {
    rm "$MINIOS_VENTOY_DIR/ventoy_persistent_map"
    printf '0 100 linear /dev/sda 2048\n' >"$MINIOS_VENTOY_DIR/ventoy_dm_table"
    mkdir -p "$MINIOS_SYS_CLASS_BLOCK/dm-8/dm"
    printf 'VentoyPart\n' >"$MINIOS_SYS_CLASS_BLOCK/dm-8/dm/name"
    : >"$MINIOS_DEV_ROOT/dm-8"
    mkdir -p "$MINIOS_DEV_ROOT/mapper"
    : >"$MINIOS_DEV_ROOT/mapper/VentoyPart"
    blkid() { :; }
    lsblk() { [ "$2" != name ] || printf 'sda\n'; }
    [ "$(manage_perch_partition /dev/mapper/ventoy setup)" = "$MINIOS_DEV_ROOT/dm-8/minios/changes" ]
    manage_perch_partition() { printf '/dev/dm-8/minios/changes\n'; }
    mounted_device() { printf '/dev/mapper/ventoy\n'; }
    mountpoint() { return 1; }
    mount_command() { printf 'mount\n'; }
    fs_options() { printf 'ro\n'; }
    find_perch_data "$WORK/iso/minios"
    [ "$(cat "$MINIOS_PERCH_STORE_FILE")" = /dev/dm-8/minios/changes ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
}

@test "ordinary Ventoy keeps the dedicated persistence partition priority" {
    rm "$MINIOS_VENTOY_DIR/ventoy_persistent_map"
    printf '0 100 linear /dev/sda 2048\n' >"$MINIOS_VENTOY_DIR/ventoy_dm_table"
    blkid() { [ "$2" != LABEL=persistence ] || printf '/dev/sda3\n'; }
    lsblk() { [ "$3" != /dev/sda3 ] || printf 'sda\n'; }
    [ "$(manage_perch_partition /dev/mapper/ventoy new)" = /dev/sda3/minios/changes ]
}

@test "ordinary Ventoy chooses the boot disk persistence label among duplicate labels" {
    rm "$MINIOS_VENTOY_DIR/ventoy_persistent_map"
    printf '0 100 linear /dev/sda 2048\n' >"$MINIOS_VENTOY_DIR/ventoy_dm_table"
    blkid() {
        case "$2" in
        LABEL=persistence) printf '%s\n' $PARTS ;;
        LABEL=resizeme) printf '/dev/sda4\n' ;;
        esac
    }
    lsblk() {
        case "$3" in
        /dev/sda3 | /dev/sda4) printf 'sda\n' ;;
        /dev/sdb3) printf 'sdb\n' ;;
        esac
    }
    for PARTS in '/dev/sda3 /dev/sdb3' '/dev/sdb3 /dev/sda3'; do
        [ "$(manage_perch_partition /dev/mapper/ventoy new)" = /dev/sda3/minios/changes ]
    done
}

@test "Ventoy resolves the selected dm name without labels or mapper symlinks" {
    : >"$MINIOS_VENTOY_DIR/ventoy_persistent_map"
    mkdir -p "$MINIOS_SYS_CLASS_BLOCK/dm-8/dm" "$MINIOS_SYS_CLASS_BLOCK/dm-9/dm"
    printf 'VentoyPart\n' >"$MINIOS_SYS_CLASS_BLOCK/dm-8/dm/name"
    printf 'vtoy_persistent\n' >"$MINIOS_SYS_CLASS_BLOCK/dm-9/dm/name"
    mknod "$MINIOS_DEV_ROOT/dm-9" b 240 9 2>/dev/null || skip "mknod is unavailable"
    blkid() { return 99; }
    [ "$(ventoy_perch_device)" = "$MINIOS_DEV_ROOT/dm-9" ]
}

@test "a missing selected mapping continues in RAM without fallback" {
    : >"$MINIOS_VENTOY_DIR/ventoy_persistent_map"
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ ! -e "$WORK/mounts" ]
    grep -q 'unavailable; continuing in memory' "$WORK/warnings"
}

@test "a selected image does not override a MiniOS boot without persistence" {
    printf 'toram\n' >"$MINIOS_CMDLINE_FILE"
    ventoy_perch_device() { return 99; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ ! -e "$WORK/mounts" ]
}

@test "Ventoy uses direct changes and workdir with no sessions or external modules" {
    printf 'perchdir=new perchmode=dynblk perchencrypt=luks toram perchtoram=full\n' >"$MINIOS_CMDLINE_FILE"
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    restore_perch_session() { return 99; }
    copy_perch_to_ram() { return 99; }
    find_perch_data "$WORK/iso/minios"
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    grep -Fxq -- "-t ext4 -o rw,noatime,errors=remount-ro /dev/dm-9 $MINIOS_VENTOY_PERCH_ROOT" "$WORK/mounts"
    grep -Fxq -- "--bind $MINIOS_VENTOY_PERCH_ROOT $CHANGES" "$WORK/mounts"
    [ -d "$MINIOS_VENTOY_PERCH_ROOT/changes" ]
    [ -d "$MINIOS_VENTOY_PERCH_ROOT/workdir" ]
    [ ! -e "$MINIOS_VENTOY_PERCH_ROOT/minios" ]
    [ ! -e "$MINIOS_VENTOY_PERCH_ROOT/session.conf" ]
    [ ! -e "$MINIOS_VENTOY_PERCH_ROOT/1" ]
    [ ! -e "$MINIOS_PERCH_ROOT_FILE" ]
    [ "$(cat "$MINIOS_PERSISTENCE_RUNDIR/store-type")" = ventoy-plugin ]
    [ "$MINIOS_PENDING_PERSISTENCE_MODE" = ventoy ]
    [ "$MINIOS_VENTOY_PERSISTENCE" = true ]
    grep -q 'perchtoram is ignored' "$WORK/warnings"
    mkdir -p "$WORK/bundles/base"
    echo_white_star() { :; }
    init_union "$CHANGES" "$WORK/union" "$WORK/bundles"
    grep -q "upperdir=$CHANGES/changes,workdir=$CHANGES/workdir " "$WORK/mounts"
}

@test "AUFS binds only the changes directory of the selected image" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    get_union_fs() { printf 'aufs\n'; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    grep -Fxq -- "--bind $MINIOS_VENTOY_PERCH_ROOT/changes $CHANGES" "$WORK/mounts"
    [ ! -e "$MINIOS_VENTOY_PERCH_ROOT/workdir" ]
}

@test "unsupported or unmountable images never activate ordinary sessions" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    device_bestfs() { printf 'exfat\n'; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ ! -e "$WORK/mounts" ]
    device_bestfs() { printf 'ext4\n'; }
    mount() { return 1; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ "$MINIOS_VENTOY_PERSISTENCE" = false ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
}

@test "a backend from another union format stays intact and boots in RAM" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    mkdir -p "$MINIOS_VENTOY_PERCH_ROOT/changes"
    printf 'aufs\n' >"$MINIOS_VENTOY_PERCH_ROOT/.minios-union"
    printf 'retained\n' >"$MINIOS_VENTOY_PERCH_ROOT/changes/saved"
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ "$MINIOS_VENTOY_PERSISTENCE" = false ]
    [ -d "$MINIOS_VENTOY_RAM_CHANGES" ]
    grep -qx retained "$MINIOS_VENTOY_PERCH_ROOT/changes/saved"
    grep -qx aufs "$MINIOS_VENTOY_PERCH_ROOT/.minios-union"
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
}

@test "invalid upper paths detach the image and leave changes in RAM" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    mkdir -p "$MINIOS_VENTOY_PERCH_ROOT"
    ln -s "$WORK/outside" "$MINIOS_VENTOY_PERCH_ROOT/changes"
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    grep -Fxq "$MINIOS_VENTOY_PERCH_ROOT" "$WORK/unmounts"
    [ ! -e "$WORK/outside" ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
}

@test "an unusable Ventoy upper retries union construction in RAM" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    mkdir -p "$WORK/bundles/base"
    echo_white_star() { :; }
    mount() {
        printf '%s\n' "$*" >>"$WORK/union-mounts"
        [ "$1" != -t ] || [ "$MINIOS_VENTOY_PERSISTENCE" != true ]
    }
    init_union "$CHANGES" "$WORK/union" "$WORK/bundles"
    [ "$MINIOS_VENTOY_PERSISTENCE" = false ]
    [ -z "$MINIOS_PENDING_PERSISTENCE_MODE" ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
    grep -q "workdir=$MINIOS_VENTOY_RAM_CHANGES/workdir " "$WORK/union-mounts"
    grep -q 'persistent upper; continuing in memory' "$WORK/warnings"
}

@test "marker publication and busy cleanup failures still choose a fresh RAM target" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    chmod() { [ "$2" != "$MINIOS_PERSISTENCE_RUNDIR" ]; }
    umount() { return 1; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    [ "$MINIOS_VENTOY_PERSISTENCE" = false ]
    [ -d "$MINIOS_VENTOY_RAM_CHANGES" ]
    [ "$MINIOS_VENTOY_RAM_CHANGES" = "$CHANGES" ]
    grep -q -- "--bind $WORK/changes-ram.* $CHANGES" "$WORK/mounts"
    [ -z "$MINIOS_PENDING_PERSISTENCE_MODE" ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/store-type" ]
    grep -q 'publish Ventoy persistence state; continuing in memory' "$WORK/warnings"
}

@test "Ventoy retries the completed union in RAM after branch or authority failures" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    echo_white_star() { :; }
    publish_union_branch_inventory() { printf '%s\n' "$1" >>"$WORK/inventory"; }
    normalize_module_whiteouts() { :; }
    for FAILURE in branch authority; do
        persistent_changes "$WORK/iso/minios" "$CHANGES"
        union_append_bundles() {
            [ "$FAILURE" != branch ] || [ "$MINIOS_VENTOY_PERSISTENCE" != true ]
        }
        perch_state_commit() {
            [ "$FAILURE" != authority ] || [ "$MINIOS_VENTOY_PERSISTENCE" != true ]
        }
        complete_union "$CHANGES" "$WORK/union" "$WORK/bundles"
        [ "$MINIOS_VENTOY_PERSISTENCE" = false ]
        [ -d "$MINIOS_VENTOY_RAM_CHANGES" ]
        grep -Fxq "$MINIOS_VENTOY_RAM_CHANGES" "$WORK/inventory"
    done
}

@test "Ventoy cleanup reads the backup command file with BusyBox awk" {
    printf '0 100 linear /dev/sda1 0\n' >"$MINIOS_VENTOY_DIR/ventoy_dm_table"
    printf 'dmsetup create VentoyPart /ventoy/ventoy_raw_table\n' >"$MINIOS_VENTOY_DIR/ventoy_iso_part_dm_cmd_bk"
    awk() { busybox awk "$@"; }
    dmsetup() { printf '%s\n' "$*" >>"$WORK/dm-cleanup"; }
    ventoy_release_mappings
    grep -Fxq 'remove VentoyPart' "$WORK/dm-cleanup"
}

@test "a busy failed root union is lazily detached before RAM recovery" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    umount() {
        printf '%s\n' "$*" >>"$WORK/unmounts"
        [ "$*" != "$WORK/union" ]
    }
    union_append_bundles() { [ "$MINIOS_VENTOY_PERSISTENCE" != true ]; }
    echo_white_star() { :; }
    publish_union_branch_inventory() { :; }
    normalize_module_whiteouts() { :; }
    complete_union "$CHANGES" "$WORK/union" "$WORK/bundles"
    grep -Fxq -- "-l $WORK/union" "$WORK/unmounts"
    [ "$MINIOS_VENTOY_PERSISTENCE" = false ]
    [ "$MINIOS_VENTOY_RAM_CHANGES" = "$CHANGES" ]
    for DIRECTORY in "$WORK"/changes-ram.*; do
        [ "$(stat -c %a "$DIRECTORY")" = 755 ]
    done
}

@test "Ventoy runtime state has no numbered session and survives initramfs preservation" {
    ventoy_perch_device() { printf '/dev/dm-9\n'; }
    persistent_changes "$WORK/iso/minios" "$CHANGES"
    perch_union_is_active() { return 0; }
    perch_store_identity() { printf '2049 2\n'; }
    perch_store_is_writable() { return 0; }
    perch_store_is_durable() { return 0; }
    perch_state_commit "$WORK/union"
    grep -qx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -qx 'mode=ventoy' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -qx 'session=unknown' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -qx 'durable=1' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    perch_state_preserve "$WORK/new-root"
    [ "$(stat -c %a "$WORK/new-root/run/initramfs/minios-persistence")" = 755 ]
    [ "$(stat -c %a "$WORK/new-root/run/initramfs/minios-persistence/store-type")" = 644 ]
    [ "$(stat -c %a "$WORK/new-root/run/initramfs/minios-persistence/boot-state")" = 600 ]
}
