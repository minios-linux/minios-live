#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    LIB="$ROOT/livekit-mos/lib/livekitlib"
    WORK=$(mktemp -d)
    MOCK="$WORK/mock"
    LOG="$WORK/commands.log"
    mkdir -p "$MOCK"
    make_mock mount
    make_mock mke2fs
    make_mock resize2fs
    make_mock e2fsck
    make_mock truncate
    make_mock @mount.dynfilefs
    make_mock cryptsetup
    make_mock losetup
    make_mock dmsetup
    make_mock df 'printf "%s\n" "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 10000000 0 9000000 0% /"'
    export PATH="$MOCK:$PATH" MINIOS_TEST_LOG="$LOG"
}

teardown() {
    rm -rf "$WORK"
}

make_mock() {
    local name=$1
    shift
    printf '%s\n' '#!/bin/sh' "printf '%s %s\\n' '$name' \"\$*\" >>\"\$MINIOS_TEST_LOG\"" "$@" >"$MOCK/$name"
    chmod +x "$MOCK/$name"
}

assert_log() {
    grep -Fqx -- "$1" "$LOG"
}

setup_dispatch() {
    TEST_MODE=$1
    TEST_FS=$2
    TEST_SIZE=${3:-64}
    TEST_DATA="$WORK/$TEST_MODE-$TEST_FS/data"
    TEST_CHANGES="$WORK/$TEST_MODE-$TEST_FS/changes"
    TEST_CHANDIR="$TEST_DATA/changes"
    mkdir -p "$TEST_CHANDIR"
    export TEST_MODE TEST_FS TEST_CHANDIR
    # shellcheck source=/dev/null
    . "$LIB"
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' new ;;
        perchmode) printf '%s\n' "$TEST_MODE" ;;
        perchsize) printf '%s\n' "$TEST_SIZE" ;;
        *) return 0 ;;
        esac
    }
    ask_disk() { printf '%s\n' "$1"; }
    manage_perch_partition() { printf '%s\n' "$2"; }
    check_write_access() { return 0; }
    persistence_requested() { return 0; }
    device_bestfs() { printf '%s\n' "$TEST_FS"; }
    get_union_fs() { printf '%s\n' overlayfs; }
    restore_perch_session() {
        if [ "$TEST_MODE" = luks ] && [ "$5" = native ]; then
            printf 'restore:new:%s\n' "$5" >>"$MINIOS_TEST_LOG"
            mkdir -p "$TEST_CHANDIR/2"
            printf '%s\n' '2 native'
        else
            printf 'restore:%s:%s\n' "$4" "$5" >>"$MINIOS_TEST_LOG"
            mkdir -p "$TEST_CHANDIR/1"
            printf '%s %s\n' 1 "$TEST_MODE"
        fi
    }
}

@test "LiveKit DynFileFS is not limited to 4000MB on FAT32" {
    setup_dispatch dynfilefs vfat 8000
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 8000"
}

@test "LiveKit native persistence binds the selected session" {
    setup_dispatch native ext4
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "mount --bind $TEST_DATA/changes/1 $TEST_CHANGES"
}

@test "LiveKit raw persistence creates a fixed-size loop image" {
    setup_dispatch raw ext4
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "truncate -s 64M $TEST_DATA/changes/1/changes.img"
    assert_log "mount -o loop $TEST_DATA/changes/1/changes.img $TEST_CHANGES"
    ! grep -Fq '@mount.dynfilefs' "$LOG"
}

@test "LiveKit DynFileFS dispatches to its existing container helper" {
    setup_dispatch dynfilefs ext4
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
}

@test "unknown persistence mode retains native to DynFileFS compatibility on FAT" {
    setup_dispatch legacy-fat vfat
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
}

@test "LUKS activation failure continues without unencrypted persistence" {
    setup_dispatch luks vfat
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    ! grep -Fq 'restore:new:native' "$LOG"
    ! grep -Fq '@mount.dynfilefs' "$LOG"
    ! grep -Fq 'mount --bind' "$LOG"
}

@test "close_owned_crypt acts only on an explicitly supplied state directory" {
    . "$LIB"
    STATE="$WORK/crypt-state"
    mkdir -p "$STATE"
    printf '%s\n' /dev/loop-owned >"$STATE/loop"
    close_owned_crypt "$STATE"
    assert_log 'losetup -d /dev/loop-owned'
    ! grep -Fq /dev/loop-unrelated "$LOG"
}

@test "persistence reserve defaults, honors perchreserve, and is clamped" {
    . "$LIB"
    cmdline_value() { return 0; }
    [ "$(perch_reserve_mb)" -eq 256 ]

    cmdline_value() { [ "$1" = perchreserve ] && printf '1000\n'; }
    [ "$(perch_reserve_mb)" -eq 1000 ]

    cmdline_value() { [ "$1" = perchreserve ] && printf '999999\n'; }
    [ "$(perch_reserve_mb)" -eq 4096 ]

    cmdline_value() { [ "$1" = perchreserve ] && printf 'garbage\n'; }
    [ "$(perch_reserve_mb)" -eq 256 ]
}

@test "free space is reported in MB from the device" {
    . "$LIB"
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 10000000 5000000 4096000 55% /"; }
    [ "$(perch_free_mb /any)" -eq 4000 ]

    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on"; }
    [ "$(perch_free_mb /any)" -eq 0 ]
}

@test "low free space triggers a preventive warning" {
    . "$LIB"
    cmdline_value() { return 0; }

    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 10000000 9900000 102400 99% /"; }
    run perch_space_warn /any
    [ "$status" -ne 0 ]
    [[ "$output" == *"only 100MB free"* ]]
    [[ "$output" == *"reserve 256MB"* ]]

    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 10000000 1000000 9000000 10% /"; }
    run perch_space_warn /any
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "container sizing keeps the reserve free on small devices" {
    setup_dispatch raw ext4 100000
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 3145728 0 3145728 0% /"; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    # 3072 MB available minus the 256 MB default reserve.
    assert_log "truncate -s 2816M $TEST_DATA/changes/1/changes.img"
}

@test "legacy session.json metadata is migrated and resumed" {
    command -v jq >/dev/null 2>&1 || skip "jq is unavailable"
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/legacy/changes"
    mkdir -p "$chandir/7"
    cat >"$chandir/session.json" <<'EOF'
{"default":"7","sessions":{"7":{"mode":"dynfilefs","union":"overlayfs","size":"2048"}}}
EOF
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" resume resume ""

    [ "$status" -eq 0 ]
    [ "$output" = "7 dynfilefs false" ]
    grep -Fqx 'default=7' "$chandir/session.conf"
    grep -Fqx 'session_mode[7]=dynfilefs' "$chandir/session.conf"
    grep -Fqx 'session_size[7]=2048' "$chandir/session.conf"
    [ -f "$chandir/session.json" ]
}

@test "clean shutdown removes running state and marks the session clean" {
    # shellcheck source=/dev/null
    . "$LIB"
    conf="$WORK/session.conf"
    state="$WORK/session-state"
    cat >"$conf" <<'EOF'
default=3
running=3
session_mode[3]=native
session_state[3]=dirty
EOF
    printf 'CONF=%s\nSESSION=3\n' "$conf" >"$state"

    session_conf_mark_clean "$state"

    ! grep -q '^running=' "$conf"
    grep -Fqx 'session_state[3]=clean' "$conf"
    [ ! -e "$state" ]
}
