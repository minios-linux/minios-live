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
    make_mock @mount.dynfilefs 'while [ $# -gt 0 ]; do if [ "$1" = "-m" ]; then mkdir -p "$2"; : >"$2/virtual.dat"; fi; shift; done'
    make_mock cryptsetup
    make_mock losetup
    make_mock df 'printf "%s\n" "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 10000000 0 9000000 0% /"'
    export PATH="$MOCK:$PATH" MINIOS_TEST_LOG="$LOG"
    export MINIOS_SESSION_STATE_FILE="$WORK/session-state"
    export MINIOS_PERSISTENCE_RUNDIR="$WORK/run-persist"
    export MINIOS_BOOT_ID_FILE="$WORK/boot-id"
    export MINIOS_PROC_MOUNTS="$WORK/mounts"
    export MINIOS_CMDLINE_FILE="$WORK/cmdline"
    export MINIOS_SYS_CLASS_BLOCK="$WORK/sys/class/block"
    export MINIOS_DEV_ROOT="$WORK/dev"
    export MINIOS_SYS_FS_AUFS="$WORK/sys/fs/aufs"
    export MINIOS_LIVEKIT_STATE_STAGE="$WORK/livekit-state-stage"
    export MINIOS_VENTOY_DIR="$WORK/ventoy"
    printf '%s\n' '11111111-2222-3333-4444-555555555555' >"$MINIOS_BOOT_ID_FILE"
    : >"$MINIOS_PROC_MOUNTS"
    : >"$MINIOS_CMDLINE_FILE"
    mkdir -p "$MINIOS_SYS_CLASS_BLOCK" "$MINIOS_DEV_ROOT" "$MINIOS_SYS_FS_AUFS"
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
    perch_store_is_durable() { return 0; }
    perch_store_is_writable() { return 0; }
    perch_union_is_active() { return 0; }
    restore_perch_session() {
        if [ "$TEST_MODE" = luks ] && [ "$5" = native ]; then
            printf 'restore:new:%s\n' "$5" >>"$MINIOS_TEST_LOG"
            mkdir -p "$TEST_CHANDIR/2"
            printf '%s\n' '2 native true'
        else
            printf 'restore:%s:%s\n' "$4" "$5" >>"$MINIOS_TEST_LOG"
            mkdir -p "$TEST_CHANDIR/1"
            printf '%s %s %s\n' 1 "$TEST_MODE" true
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
    perch_state_commit "$WORK/union"
    assert_log "truncate -s 64M $TEST_DATA/changes/1/changes.img"
    assert_log "mount -o loop,errors=remount-ro $TEST_DATA/changes/1/changes.img $TEST_CHANGES"
    ! grep -Fq '@mount.dynfilefs' "$LOG"
}

@test "native metadata failure unwinds activation and removes a new session" {
    setup_dispatch native ext4
    session_conf_commit() { return 1; }
    perch_activation_unwind() { printf 'unwind %s\n' "$1" >>"$MINIOS_TEST_LOG"; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "unwind $TEST_CHANGES"
    [ ! -d "$TEST_CHANDIR/1" ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ -z "$MINIOS_PENDING_PERSISTENCE_SESSION" ]
}

@test "DynFileFS metadata failure unwinds activation and removes a new session" {
    setup_dispatch dynfilefs vfat
    make_mock @mount.dynfilefs 'file= mountpoint=; while [ $# -gt 0 ]; do case "$1" in -f) file=$2; shift ;; -m) mountpoint=$2; shift ;; esac; shift; done; mkdir -p "$mountpoint"; : >"$mountpoint/virtual.dat"; : >"$file"; : >"$file.0"'
    session_conf_commit() { return 1; }
    perch_activation_unwind() { printf 'unwind %s\n' "$1" >>"$MINIOS_TEST_LOG"; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "unwind $TEST_CHANGES"
    [ ! -d "$TEST_CHANDIR/1" ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ -z "$MINIOS_PENDING_PERSISTENCE_SESSION" ]
}

@test "raw metadata failure unwinds activation and removes a new session" {
    setup_dispatch raw ext4
    make_mock truncate ': >"$3"'
    session_conf_commit() { return 1; }
    perch_activation_unwind() { printf 'unwind %s\n' "$1" >>"$MINIOS_TEST_LOG"; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "unwind $TEST_CHANGES"
    [ ! -d "$TEST_CHANDIR/1" ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ -z "$MINIOS_PENDING_PERSISTENCE_SESSION" ]
}

@test "metadata rollback preserves an existing session" {
    setup_dispatch raw ext4
    mkdir -p "$TEST_CHANDIR/1"
    printf keep >"$TEST_CHANDIR/1/marker"
    printf container >"$TEST_CHANDIR/1/changes.img"
    restore_perch_session() { printf '%s\n' '1 raw false'; }
    session_conf_commit() { return 1; }
    perch_activation_unwind() { printf 'unwind %s\n' "$1" >>"$MINIOS_TEST_LOG"; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "unwind $TEST_CHANGES"
    [ "$(cat "$TEST_CHANDIR/1/marker")" = keep ]
    [ "$(cat "$TEST_CHANDIR/1/changes.img")" = container ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "invalid SquashFS generations fail closed instead of falling back to native" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=manual' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { return 1; }
    squashfs_upper_unwind() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    run grep -Fq "mount --bind $TEST_CHANDIR/1 $TEST_CHANGES" "$LOG"
    [ "$status" -ne 0 ]
    run grep -Fq '@mount.dynfilefs' "$LOG"
    [ "$status" -ne 0 ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'could not be restored' \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "SquashFS success is published only after union verification" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=manual' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { SQUASHFS_ACTIVE_GENERATION=current; return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    [ ! -f "$MINIOS_PERSISTENCE_RUNDIR/boot-state" ]
    perch_state_commit "$WORK/union"

    grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'mode=squashfs' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'active_generation=current' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'running=1' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'session_state[1]=dirty' "$TEST_CHANDIR/session.conf"
}

@test "SquashFS restore uses only the current changes.sb generation" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=manual' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() {
        [ "$#" -eq 1 ] && [ "$1" = "$TEST_CHANGES" ] || return 1
        SQUASHFS_ACTIVE_GENERATION=current
    }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'active_generation=current' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "legacy SquashFS without policy defaults to manual" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { SQUASHFS_ACTIVE_GENERATION=current; return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    [ "$MINIOS_SQUASHFS_POLICY" = manual ]
}

@test "shutdown-policy SquashFS restores the current snapshot" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=shutdown' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { SQUASHFS_ACTIVE_GENERATION=current; return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'mode=squashfs' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'session_policy[1]=shutdown' "$TEST_CHANDIR/session.conf"
}

@test "dirty SquashFS session warns that the last saved snapshot is being restored" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=shutdown' 'session_state[1]=dirty' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { SQUASHFS_ACTIVE_GENERATION=current; return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    grep -Fq 'did not finish cleanly; restoring the last successfully saved snapshot' \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "invalid SquashFS save policy fails closed" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=sometimes' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'invalid save policy' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "failed current SquashFS generation falls back to RAM without rollback" {
    setup_dispatch squashfs ext4
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=manual' >"$TEST_CHANDIR/session.conf"
    squashfs_generation_restore() { return 1; }
    squashfs_upper_unwind() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'could not be restored; continuing in memory' \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    ! grep -Fq 'rollback generation' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "runtime publication failure leaves SquashFS metadata uncommitted" {
    setup_dispatch squashfs ext4
    conf="$TEST_CHANDIR/session.conf"
    printf '%s\n' 'default=1' 'session_mode[1]=squashfs' \
        'session_policy[1]=manual' >"$conf"
    MINIOS_SQUASHFS_CONF="$conf"
    perch_state_prepare squashfs 1 "$TEST_CHANDIR" current "$TEST_CHANGES" "$conf"
    perch_state_publish() { [ "$1" != ok ]; }

    run perch_state_commit "$WORK/union"

    [ "$status" -ne 0 ]
    ! grep -q '^running=' "$conf"
    ! grep -q '^session_state\[1\]=dirty$' "$conf"
}

@test "new SquashFS selection does not reserve a numbered directory" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/new-squashfs/changes"
    mkdir -p "$chandir"
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" new new squashfs

    [ "$status" -ne 0 ]
    run bash -c 'find "$1" -mindepth 1 -maxdepth 1 -type d -name "[0-9]*" -print -quit' _ "$chandir"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "$chandir/session.conf" ]
    [ ! -f "$chandir/session.json" ]
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

@test "legacy ntfs and near matches do not masquerade as ntfs3" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_PROC_FILESYSTEMS="$WORK/filesystems"
    printf '\tntfs\n\tntfs3_helper\n' >"$MINIOS_PROC_FILESYSTEMS"
    debug_log() { :; }
    device_tag() { printf '%s\n' ntfs; }
    lsmod() { printf '%s\n' 'ntfs 123 0'; }
    modprobe() { return 1; }

    run device_bestfs /dev/mock

    [ "$status" -eq 0 ]
    [ "$output" = ntfs-3g ]
}

@test "built-in ntfs3 is detected without an lsmod row" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_PROC_FILESYSTEMS="$WORK/filesystems"
    printf '\tntfs3\n' >"$MINIOS_PROC_FILESYSTEMS"
    debug_log() { :; }
    device_tag() { printf '%s\n' ntfs; }
    lsmod() { :; }
    modprobe() { return 1; }

    run device_bestfs /dev/mock

    [ "$status" -eq 0 ]
    [ "$output" = ntfs3 ]
}

@test "loadable ntfs3 is detected after modprobe" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_PROC_FILESYSTEMS="$WORK/filesystems"
    printf '\tntfs\n' >"$MINIOS_PROC_FILESYSTEMS"
    debug_log() { :; }
    device_tag() { printf '%s\n' ntfs; }
    modprobe() {
        [ "$1" = ntfs3 ] || return 1
        printf '\tntfs3\n' >>"$MINIOS_PROC_FILESYSTEMS"
    }

    run device_bestfs /dev/mock

    [ "$status" -eq 0 ]
    [ "$output" = ntfs3 ]
}

@test "LUKS activation failure continues without unencrypted persistence" {
    setup_dispatch luks vfat
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    ! grep -Fq 'restore:new:native' "$LOG"
    ! grep -Fq '@mount.dynfilefs' "$LOG"
    ! grep -Fq 'mount --bind' "$LOG"
    [ ! -f "$TEST_CHANDIR/session.conf" ] || ! grep -q '^default=' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    ! grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'persistence' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "close_owned_crypt removes only its explicitly supplied state" {
    . "$LIB"
    STATE="$WORK/crypt-state"
    OTHER="$WORK/unrelated-state"
    mkdir -p "$STATE" "$OTHER"
    close_owned_crypt "$STATE"
    [ ! -e "$STATE" ]
    [ -d "$OTHER" ]
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


@test "automatic DynFileFS sizing also keeps perchreserve free" {
    setup_dispatch dynfilefs ext4 0
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 9216000 0 9216000 0% /"; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    # 9000 MB available minus 256 MB reserve, rounded down to a 1000 MB boundary.
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 8000"
}

@test "automatic DynFileFS sizing never grows past a small device" {
    setup_dispatch dynfilefs ext4 0
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 3145728 0 3145728 0% /"; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 2000"
}

@test "jq-capable initrd resumes a json-only session" {
    command -v jq >/dev/null 2>&1 || skip "jq is unavailable"
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/legacy/changes"
    mkdir -p "$chandir/7"
    cat >"$chandir/session.json" <<'EOF'
{"default":"7","sessions":{"7":{"mode":"dynfilefs","union":"overlayfs","size":"2048","policy":"shutdown"}}}
EOF
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" resume resume ""

    [ "$status" -eq 0 ]
    [ "$output" = "7 dynfilefs false" ]
    grep -Fqx 'default=7' "$chandir/session.conf"
    grep -Fqx 'session_mode[7]=dynfilefs' "$chandir/session.conf"
    grep -Fqx 'session_size[7]=2048' "$chandir/session.conf"
    grep -Fqx 'session_policy[7]=shutdown' "$chandir/session.conf"
    [ -f "$chandir/session.json" ]
}

@test "jq-capable initrd selects json when both formats exist" {
    command -v jq >/dev/null 2>&1 || skip "jq is unavailable"
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/equal/changes"
    mkdir -p "$chandir/3" "$chandir/7"
    printf '%s\n' 'default=3' 'session_mode[3]=native' >"$chandir/session.conf"
    cat >"$chandir/session.json" <<'EOF'
{"default":"7","sessions":{"7":{"mode":"dynfilefs","union":"overlayfs","size":"2048","policy":"shutdown"}}}
EOF
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" resume resume ""

    [ "$status" -eq 0 ]
    [ "$output" = "7 dynfilefs false" ]
    grep -Fqx 'default=7' "$chandir/session.conf"
    grep -Fqx 'session_policy[7]=shutdown' "$chandir/session.conf"
}

@test "jq metadata rejects nonnumeric session ids" {
    command -v jq >/dev/null 2>&1 || skip "jq is unavailable"
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/invalid/changes"
    mkdir -p "$chandir"
    printf '%s\n' '{"default":"../modules","sessions":{"../modules":{"mode":"native"}}}' \
        >"$chandir/session.json"

    run session_metadata_select "$chandir"

    [ "$status" -ne 0 ]
    [ ! -f "$chandir/session.conf" ]
}

@test "initrd without jq selects conf and removes stale json on commit" {
    # shellcheck source=/dev/null
    . "$LIB"
    command() {
        [ "$1" != -v ] || [ "$2" != jq ] || return 1
        builtin command "$@"
    }
    chandir="$WORK/conf/changes"
    mkdir -p "$chandir"
    printf '%s\n' 'default=3' 'session_mode[3]=native' >"$chandir/session.conf"
    printf '%s\n' '{"default":"7","sessions":{"7":{"mode":"raw"}}}' \
        >"$chandir/session.json"

    [ "$(session_metadata_select "$chandir")" = "$chandir/session.conf" ]
    session_conf_commit "$chandir/session.conf" 3 native 5.0 standard overlayfs 0

    grep -Fqx 'default=3' "$chandir/session.conf"
    [ ! -f "$chandir/session.json" ]
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

@test "successful activation publishes an ok runtime marker and no warning" {
    setup_dispatch raw ext4
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"
    grep -Fqx 'default=1' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'boot_id=11111111-2222-3333-4444-555555555555' \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'mode=raw' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'session=1' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'durable=1' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'writable=1' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx "sessions_device=$(stat -c '%d' "$TEST_CHANDIR")" \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx "sessions_inode=$(stat -c '%i' "$TEST_CHANDIR")" \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'active_generation=current' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ "$(wc -l <"$MINIOS_PERSISTENCE_RUNDIR/boot-state")" -eq 9 ]
    [ "$(stat -c '%a' "$MINIOS_PERSISTENCE_RUNDIR/boot-state")" = 600 ]
    [ ! -f "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
}

@test "volatile toram store stays active without durable save authority" {
    setup_dispatch raw ext4
    perch_store_is_durable() { return 1; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    grep -Fqx 'default=1' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'durable=0' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'writable=1' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'active_generation=current' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ ! -f "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
}

@test "successful persistence is not published before the union is observed" {
    setup_dispatch raw ext4
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    [ ! -f "$MINIOS_PERSISTENCE_RUNDIR/boot-state" ]
    perch_union_is_active() { return 1; }

    if perch_state_commit "$WORK/union"; then
        false
    fi
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'not committed into the root union' \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    [ -z "$MINIOS_PENDING_PERSISTENCE_SESSION" ]
}

@test "durability follows a loop backing file and rejects tmpfs" {
    # shellcheck source=/dev/null
    . "$LIB"
    mkdir -p "$WORK/ram/store"
    cat >"$MINIOS_PROC_MOUNTS" <<EOF
tmpfs $WORK/ram tmpfs rw,nosuid,nodev 0 0
$MINIOS_DEV_ROOT/loop7 $WORK/ram/store ext4 rw,relatime 0 0
EOF
    losetup() {
        printf '%s\n' "$MINIOS_DEV_ROOT/loop7: []: ($WORK/ram/persistence.img)"
    }

    run perch_store_is_durable "$WORK/ram/store/changes"

    [ "$status" -ne 0 ]
}

@test "durability accepts a writable supported block filesystem" {
    # shellcheck source=/dev/null
    . "$LIB"
    mkdir -p "$WORK/disk/changes"
    mkdir -p "$MINIOS_SYS_CLASS_BLOCK/sda1"
    printf '%s\n' 0 >"$MINIOS_SYS_CLASS_BLOCK/sda1/ro"
    printf '%s\n' "$MINIOS_DEV_ROOT/sda1 $WORK/disk ext4 rw,relatime 0 0" \
        >"$MINIOS_PROC_MOUNTS"

    perch_store_is_durable "$WORK/disk/changes"
    perch_store_is_writable "$WORK/disk/changes"
}

@test "durability rejects a device-mapper chain backed by tmpfs" {
    # shellcheck source=/dev/null
    . "$LIB"
    mkdir -p "$WORK/ram" "$WORK/store" \
        "$MINIOS_SYS_CLASS_BLOCK/dm-0/slaves" \
        "$MINIOS_SYS_CLASS_BLOCK/loop7"
    printf '%s\n' 0 >"$MINIOS_SYS_CLASS_BLOCK/dm-0/ro"
    printf '%s\n' 0 >"$MINIOS_SYS_CLASS_BLOCK/loop7/ro"
    ln -s ../../loop7 "$MINIOS_SYS_CLASS_BLOCK/dm-0/slaves/loop7"
    cat >"$MINIOS_PROC_MOUNTS" <<EOF
tmpfs $WORK/ram tmpfs rw,nosuid,nodev 0 0
$MINIOS_DEV_ROOT/dm-0 $WORK/store ext4 rw,relatime 0 0
EOF
    readlink() { [ "$1" = -f ] && printf '%s\n' "$2"; }
    losetup() {
        printf '%s\n' "$MINIOS_DEV_ROOT/loop7: []: ($WORK/ram/persistence.img)"
    }

    run perch_store_is_durable "$WORK/store/changes"

    [ "$status" -ne 0 ]
}

@test "durability accepts device-mapper only when every slave is physical" {
    # shellcheck source=/dev/null
    . "$LIB"
    mkdir -p "$WORK/store" "$MINIOS_SYS_CLASS_BLOCK/dm-0/slaves" \
        "$MINIOS_SYS_CLASS_BLOCK/sda1"
    printf '%s\n' 0 >"$MINIOS_SYS_CLASS_BLOCK/dm-0/ro"
    printf '%s\n' 0 >"$MINIOS_SYS_CLASS_BLOCK/sda1/ro"
    ln -s ../../sda1 "$MINIOS_SYS_CLASS_BLOCK/dm-0/slaves/sda1"
    printf '%s\n' "$MINIOS_DEV_ROOT/dm-0 $WORK/store ext4 rw,relatime 0 0" \
        >"$MINIOS_PROC_MOUNTS"
    readlink() { [ "$1" = -f ] && printf '%s\n' "$2"; }

    perch_store_is_durable "$WORK/store/changes"

    printf '%s\n' 1 >"$MINIOS_SYS_CLASS_BLOCK/sda1/ro"
    run perch_store_is_durable "$WORK/store/changes"
    [ "$status" -ne 0 ]
}

@test "post-union authority binds the expected OverlayFS upper" {
    # shellcheck source=/dev/null
    . "$LIB"
    changes="$WORK/changes"
    union="$WORK/union"
    mkdir -p "$changes/changes" "$changes/workdir" "$union"
    printf '%s\n' \
        "overlay $union overlay rw,lowerdir=/lower,upperdir=$changes/changes,workdir=$changes/workdir 0 0" \
        >"$MINIOS_PROC_MOUNTS"

    perch_union_is_active "$union" "$changes"
    run perch_union_is_active "$union" "$WORK/other-changes"
    [ "$status" -ne 0 ]
}

@test "post-union authority binds the expected AUFS writable branch" {
    # shellcheck source=/dev/null
    . "$LIB"
    changes="$WORK/changes"
    union="$WORK/union"
    mkdir -p "$changes" "$union" "$MINIOS_SYS_FS_AUFS/si_test"
    printf '%s\n' "$changes=rw" >"$MINIOS_SYS_FS_AUFS/si_test/br0"
    printf '%s\n' "none $union aufs rw,si=test 0 0" >"$MINIOS_PROC_MOUNTS"

    perch_union_is_active "$union" "$changes"
    printf '%s\n' "$WORK/other=rw" >"$MINIOS_SYS_FS_AUFS/si_test/br0"
    run perch_union_is_active "$union" "$changes"
    [ "$status" -ne 0 ]
}

@test "forced OverlayFS skips AUFS branch append even when AUFS is available" {
    # shellcheck source=/dev/null
    . "$LIB"
    bundles="$WORK/bundles"
    union="$WORK/union"
    mkdir -p "$bundles/01-core" "$union"
    printf '%s\n' "overlay $union overlay rw,upperdir=$WORK/changes/changes 0 0" \
        >"$MINIOS_PROC_MOUNTS"
    debug_log() { :; }
    aufs_is_supported() { return 0; }
    mount() { printf '%s\n' called >>"$MINIOS_TEST_LOG"; return 1; }

    union_append_bundles "$bundles" "$union"

    [ ! -s "$MINIOS_TEST_LOG" ]
}

@test "AUFS branch append failure propagates after attempting every branch" {
    # shellcheck source=/dev/null
    . "$LIB"
    bundles="$WORK/bundles"
    union="$WORK/union"
    mkdir -p "$bundles/01-core" "$bundles/02-broken" "$bundles/03-apps" "$union"
    printf '%s\n' "none $union aufs rw,si=test 0 0" >"$MINIOS_PROC_MOUNTS"
    mount() {
        printf '%s\n' "$*" >>"$MINIOS_TEST_LOG"
        case "$*" in *02-broken*) return 1 ;; esac
        return 0
    }

    run union_append_bundles "$bundles" "$union"

    [ "$status" -ne 0 ]
    grep -Fq '01-core=rr+wh' "$MINIOS_TEST_LOG"
    grep -Fq '02-broken=rr+wh' "$MINIOS_TEST_LOG"
    grep -Fq '03-apps=rr+wh' "$MINIOS_TEST_LOG"
}

@test "toram does not request persistence without explicit perch" {
    # shellcheck source=/dev/null
    . "$LIB"
    for cmdline in \
        'boot=live toram=full' \
        'boot=live toram=full noperch' \
        'boot=live toram=full option=perch' \
        'boot=live toram=full perchance=yes'; do
        printf '%s\n' "$cmdline" >"$MINIOS_CMDLINE_FILE"
        run persistence_requested
        [ "$status" -ne 0 ]
    done

    printf '%s\n' 'boot=live toram=full perch' >"$MINIOS_CMDLINE_FILE"
    persistence_requested
    printf '%s\n' 'boot=live toram=full perchdir=resume' >"$MINIOS_CMDLINE_FILE"
    persistence_requested
    printf '%s\n' 'boot=live toram=full perchmode=luks' >"$MINIOS_CMDLINE_FILE"
    persistence_requested
}

@test "toram copies changes only when explicit perch is present" {
    # shellcheck source=/dev/null
    . "$LIB"
    data="$WORK/media/minios"
    changes="$WORK/memory/changes"
    mkdir -p "$data/changes" "$changes"
    printf '%s\n' config >"$data/config.conf"
    printf '%s\n' module >"$data/01-core.sb"
    printf '%s\n' user-data >"$data/changes/user-file"
    mounted_dir() { :; }
    mounted_device() { :; }
    umount() { return 1; }

    printf '%s\n' 'boot=live toram=full' >"$MINIOS_CMDLINE_FILE"
    first_ram=$(copy_to_ram "$data" "$changes")
    [ -f "$first_ram/01-core.sb" ]
    [ ! -e "$first_ram/changes/user-file" ]
    rm -rf "$first_ram"

    printf '%s\n' 'boot=live toram=full perch' >"$MINIOS_CMDLINE_FILE"
    second_ram=$(copy_to_ram "$data" "$changes")
    [ -f "$second_ram/01-core.sb" ]
    [ -f "$second_ram/changes/user-file" ]
}

@test "Ventoy cleanup removes the ISO, raw partition, and unused persistence mappings" {
    # shellcheck source=/dev/null
    . "$LIB"
    make_mock dmsetup
    mkdir -p "$MINIOS_VENTOY_DIR"
    printf '%s\n' '0 100 linear /dev/sda1 2048' >"$MINIOS_VENTOY_DIR/ventoy_dm_table"
    printf '%s\n' 'dmsetup create sda1 /ventoy/ventoy_raw_table' >"$MINIOS_VENTOY_DIR/ventoy_iso_part_dm_cmd"
    : >"$MINIOS_VENTOY_DIR/ventoy_persistent_map"

    ventoy_release_mappings

    assert_log "dmsetup remove vtoy_persistent"
    assert_log "dmsetup remove sda1"
    assert_log "dmsetup remove ventoy"
}

@test "toram releases Ventoy mappings only after a successful RAM detach" {
    # shellcheck source=/dev/null
    . "$LIB"
    data="$WORK/media/minios"
    changes="$WORK/memory/changes"
    mkdir -p "$data" "$changes"
    printf '%s\n' config >"$data/config.conf"
    printf '%s\n' module >"$data/01-core.sb"
    mounted_dir() { printf '%s\n' "$WORK/media"; }
    mounted_device() { :; }
    umount() { return 0; }
    ventoy_release_mappings() { printf '%s\n' cleanup >>"$MINIOS_TEST_LOG"; }
    printf '%s\n' 'boot=live toram=full' >"$MINIOS_CMDLINE_FILE"

    result=$(copy_to_ram "$data" "$changes")

    [ "$result" = "$data" ]
    grep -Fqx cleanup "$LOG"
}

@test "toram keeps Ventoy mappings when source detach fails" {
    # shellcheck source=/dev/null
    . "$LIB"
    data="$WORK/media/minios"
    changes="$WORK/memory/changes"
    mkdir -p "$data" "$changes"
    printf '%s\n' config >"$data/config.conf"
    printf '%s\n' module >"$data/01-core.sb"
    mounted_dir() { printf '%s\n' "$WORK/media"; }
    mounted_device() { :; }
    umount() { return 1; }
    ventoy_release_mappings() { printf '%s\n' cleanup >>"$MINIOS_TEST_LOG"; }
    printf '%s\n' 'boot=live toram=full' >"$MINIOS_CMDLINE_FILE"

    result=$(copy_to_ram "$data" "$changes")

    [ "$result" = "$WORK/memory/toram" ]
    ! grep -Fqx cleanup "$LOG"
}

@test "toram keeps Ventoy mappings when persistence is requested" {
    # shellcheck source=/dev/null
    . "$LIB"
    data="$WORK/media/minios"
    changes="$WORK/memory/changes"
    mkdir -p "$data/changes" "$changes"
    printf '%s\n' config >"$data/config.conf"
    printf '%s\n' module >"$data/01-core.sb"
    mounted_dir() { printf '%s\n' "$WORK/media"; }
    mounted_device() { :; }
    umount() { return 0; }
    ventoy_release_mappings() { printf '%s\n' cleanup >>"$MINIOS_TEST_LOG"; }
    printf '%s\n' 'boot=live toram=full perch' >"$MINIOS_CMDLINE_FILE"

    result=$(copy_to_ram "$data" "$changes")

    [ "$result" = "$data" ]
    ! grep -Fqx cleanup "$LOG"
}

@test "failed runtime publication sanitizes untrusted scalar fields" {
    # shellcheck source=/dev/null
    . "$LIB"

    run perch_state_publish failed 'bad=mode' '../session'

    [ "$status" -ne 0 ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'mode=unknown' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'session=unknown' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ "$(wc -l <"$MINIOS_PERSISTENCE_RUNDIR/boot-state")" -eq 9 ]
}

@test "explicit persistence write failure publishes degraded runtime state" {
    setup_dispatch raw ext4
    check_write_access() { return 1; }
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' new ;;
        perchmode) printf '%s\n' raw ;;
        perchsize) printf '%s\n' 64 ;;
        *) return 0 ;;
        esac
    }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'not writable' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    [ ! -f "$TEST_CHANDIR/session.conf" ]
    [ -z "$MINIOS_PENDING_PERSISTENCE_SESSION" ]
}

@test "resume without writable persistence continues in memory without error state" {
    setup_dispatch raw ext4
    check_write_access() { return 1; }
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' resume ;;
        perchmode) printf '%s\n' raw ;;
        perchsize) printf '%s\n' 64 ;;
        *) return 0 ;;
        esac
    }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/boot-state" ]
    [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
    [ ! -f "$TEST_CHANDIR/session.conf" ]
    [ -z "$MINIOS_PENDING_PERSISTENCE_SESSION" ]
}

@test "runtime state is preserved at the post-switch-root consumer path" {
    # shellcheck source=/dev/null
    . "$LIB"
    root="$WORK/new-root"
    mkdir -p "$root/run/initramfs"
    perch_state_publish failed raw 1 || true

    perch_state_preserve "$root"

    preserved="$root/run/initramfs/minios-persistence/boot-state"
    [ -f "$preserved" ]
    grep -Fqx 'boot_id=11111111-2222-3333-4444-555555555555' "$preserved"
    grep -Fqx 'boot_level=failed' "$preserved"
    [ "$(stat -c '%a' "$preserved")" = 600 ]
}

@test "LiveKit state staging maps from old root to the consumer path" {
    # shellcheck source=/dev/null
    . "$LIB"
    perch_state_publish failed raw 1 || true

    perch_state_stage_livekit

    staged="$MINIOS_LIVEKIT_STATE_STAGE/boot-state"
    [ -f "$staged" ]
    grep -Fqx 'boot_level=failed' "$staged"
    [ "$(stat -c '%a' "$staged")" = 600 ]
}

@test "DynFileFS backend failure continues in memory without publishing" {
    setup_dispatch dynfilefs ext4
    make_mock @mount.dynfilefs 'exit 1'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    # No session published as default.
    [ ! -f "$TEST_CHANDIR/session.conf" ] || ! grep -q '^default=' "$TEST_CHANDIR/session.conf"
    # No inner filesystem was created or mounted in RAM.
    ! grep -Fq 'mount -o loop' "$LOG"
    # Failure is recorded for the runtime guard and captured for the GUI (U1).
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'persistence' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "filesystem creation failure continues in memory without publishing" {
    setup_dispatch raw ext4
    make_mock mke2fs 'exit 1'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    ! grep -Fq 'mount -o loop' "$LOG"
    [ ! -f "$TEST_CHANDIR/session.conf" ] || ! grep -q '^default=' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "e2fsck failure keeps the container read-only and does not publish" {
    setup_dispatch raw ext4
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/changes.img"
    make_mock e2fsck 'exit 2'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "e2fsck -p $TEST_CHANDIR/1/changes.img"
    ! grep -Fq 'mount -o loop' "$LOG"
    [ ! -f "$TEST_CHANDIR/session.conf" ] || ! grep -q '^default=' "$TEST_CHANDIR/session.conf"
    grep -Fq 'fsck' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "automatic resume creates the first session on an empty writable store" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/auto-empty/changes"
    mkdir -p "$chandir"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" resume resume "" true

    [ "$status" -eq 0 ]
    [ "$output" = "1 native true" ]
    [ -d "$chandir/1" ]
}

@test "automatic resume creates a new session on union mismatch" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/auto-mismatch/changes"
    mkdir -p "$chandir/1"
    printf '%s\n' 'default=1' 'session_mode[1]=native' \
        'session_union[1]=aufs' >"$chandir/session.conf"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" resume resume "" true

    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | tail -n 1)" = "2 native true" ]
    [ -d "$chandir/2" ]
}


@test "automatic resume records the union mismatch for Session Manager" {
    # shellcheck source=/dev/null
    . "$LIB"
    debug_log() { :; }
    chandir="$WORK/auto-union-warning/changes"
    mkdir -p "$chandir/1"
    printf '%s\n' 'default=1' 'session_mode[1]=native' \
        'session_union[1]=aufs' >"$chandir/session.conf"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    result=$(restore_perch_session /dev/test "$chandir" resume resume "" true 2>"$WORK/auto-union-warning.err")

    [ "$result" = "2 native true" ]
    grep -Fq 'union filesystem mismatch detected' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    grep -Fq 'Creating a new session' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    grep -Fq 'union filesystem mismatch detected' "$WORK/auto-union-warning.err"
}

@test "automatic resume records persistence mode mismatch for Session Manager" {
    # shellcheck source=/dev/null
    . "$LIB"
    debug_log() { :; }
    chandir="$WORK/auto-mode-warning/changes"
    mkdir -p "$chandir/1"
    printf '%s\n' 'default=1' 'session_mode[1]=native' >"$chandir/session.conf"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    restore_perch_session /dev/test "$chandir" resume resume raw true >/dev/null

    grep -Fq 'persistence mode changed' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    grep -Fq '(native -> raw) Creating a new session' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "new session id is numeric max+1 and never reuses a directory" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/alloc/changes"
    mkdir -p "$chandir/9" "$chandir/10" "$chandir/11"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" new new ""

    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | awk '{print $1}')" = "12" ]
    [ -d "$chandir/12" ]
}

@test "boot warning capture records one structured record for a multiline notification" {
    # shellcheck source=/dev/null
    . "$LIB"
    boot_warning_notify warning space "disk almost full" "free space before saving"
    boot_warning_log error persistence "backend gone"
    [ "$(grep -c '	space	disk almost full free space before saving$' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings")" -eq 1 ]
    [ "$(grep -c '	persistence	backend gone$' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings")" -eq 1 ]
}

@test "resize2fs failure warns but still mounts the filesystem" {
    # resize2fs may fail if the filesystem is nearly full or the kernel
    # module is missing. The filesystem is still valid at its previous size,
    # so we must mount it rather than aborting activation.
    setup_dispatch raw ext4
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/changes.img"
    make_mock resize2fs 'exit 1'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    # The session IS published (activation continued despite resize2fs failure).
    grep -Fqx 'default=1' "$TEST_CHANDIR/session.conf"
    assert_log "mount -o loop,errors=remount-ro $TEST_CHANDIR/1/changes.img $TEST_CHANGES"
    # A warning is recorded for the resize failure.
    grep -Fq 'resize' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "session_conf_commit synchronizes session.json when jq is available" {
    command -v jq >/dev/null 2>&1 || skip "jq is unavailable"
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/sync/changes"
    mkdir -p "$chandir"
    get_union_fs() { printf '%s\n' overlayfs; }

    PERCHDIR=3; PERCHMODE=raw; PERCHSIZE=0
    local SESSIONS="$chandir/session.conf"
    session_conf_commit "$SESSIONS" 3 raw 5.0 standard overlayfs 2000

    # Both capability-selected representations must contain the same update.
    grep -Fqx 'default=3' "$chandir/session.conf"
    # json mirror must reflect the same data
    [ -f "$chandir/session.json" ]
    [ "$(jq -r '.default' "$chandir/session.json")" = "3" ]
    [ "$(jq -r '.sessions["3"].mode' "$chandir/session.json")" = "raw" ]
}

@test "session commit preserves size and underscore metadata" {
    command -v jq >/dev/null 2>&1 || skip "jq is unavailable"
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/fields/changes"
    mkdir -p "$chandir"
    printf '%s\n' \
        'default=3' \
        'session_mode[3]=raw' \
        'session_size[3]=2000' \
        'session_size_mb[3]=2000' \
        'session_policy[3]=shutdown' >"$chandir/session.conf"

    session_conf_commit "$chandir/session.conf" 3 raw 5.0 standard overlayfs 0

    grep -Fqx 'session_size[3]=2000' "$chandir/session.conf"
    grep -Fqx 'session_size_mb[3]=2000' "$chandir/session.conf"
    [ "$(jq -r '.sessions["3"].size' "$chandir/session.json")" = "2000" ]
    [ "$(jq -r '.sessions["3"].size_mb' "$chandir/session.json")" = "2000" ]
    [ "$(jq -r '.sessions["3"].policy' "$chandir/session.json")" = "shutdown" ]
}
