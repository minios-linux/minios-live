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
    # Never let unit tests issue a host-wide sync; production code still calls
    # sync, but the test suite must keep I/O scoped to its private fixture.
    make_mock sync
    make_mock @mount.dynfilefs 'while [ $# -gt 0 ]; do if [ "$1" = "-m" ]; then mkdir -p "$2"; : >"$2/virtual.dat"; fi; shift; done'
    make_mock dynblk 'case "$1" in create|load) printf "%s\n" /dev/dynblk7 ;; limits) printf "max_capacity_mib: 67108864\n" ;; esac'
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
    export MINIOS_EFIVARS_DIR="$WORK/efivars"
    export MINIOS_LIVEKIT_STATE_STAGE="$WORK/livekit-state-stage"
    export MINIOS_VENTOY_DIR="$WORK/ventoy"
    export MINIOS_PROC_MEMINFO="$WORK/meminfo"
    printf '%s\n' 'MemTotal:       4194304 kB' 'MemAvailable:   3145728 kB' 'SwapFree:       1048576 kB' >"$MINIOS_PROC_MEMINFO"
    printf '%s\n' '11111111-2222-3333-4444-555555555555' >"$MINIOS_BOOT_ID_FILE"
    : >"$MINIOS_PROC_MOUNTS"
    : >"$MINIOS_CMDLINE_FILE"
    mkdir -p "$MINIOS_SYS_CLASS_BLOCK" "$MINIOS_DEV_ROOT" "$MINIOS_SYS_FS_AUFS" "$MINIOS_EFIVARS_DIR"
}

set_secure_boot() {
    local value=${1:-1}
    printf '\007\000\000\000' >"$MINIOS_EFIVARS_DIR/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
    if [ "$value" = 1 ]; then
        printf '\001' >>"$MINIOS_EFIVARS_DIR/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
    else
        printf '\000' >>"$MINIOS_EFIVARS_DIR/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
    fi
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
    TEST_ENCRYPT=${4:-none}
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
        perchencrypt) printf '%s\n' "$TEST_ENCRYPT" ;;
        perchcomp) printf '%s\n' none ;;
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
    dynblk_device_ready() { dynblk_device_valid "$1"; }
    restore_perch_session() {
        if [ "$TEST_MODE" = luks ] && [ "$5" = native ]; then
            printf 'restore:new:%s\n' "$5" >>"$MINIOS_TEST_LOG"
            mkdir -p "$TEST_CHANDIR/2"
            printf '%s\n' '2 native true none none'
        else
            printf 'restore:%s:%s\n' "$4" "$5" >>"$MINIOS_TEST_LOG"
            mkdir -p "$TEST_CHANDIR/1"
            if [ -f "$TEST_CHANDIR/session.conf" ]; then
                printf '%s %s %s %s %s\n' 1 "$5" false "${7:-none}" "${8:-none}"
            else
                printf '%s %s %s %s %s\n' 1 "$5" true "${7:-none}" "${8:-none}"
            fi
        fi
    }
}

@test "perchcomp alone requests persistence handling" {
    # shellcheck source=/dev/null
    . "$LIB"
    printf '%s\n' 'quiet perchcomp=zstd' >"$MINIOS_CMDLINE_FILE"

    persistence_requested
}

@test "Secure Boot efivar disables DynBlk and VMDK" {
    # shellcheck source=/dev/null
    . "$LIB"
    set_secure_boot 1

    secure_boot_enabled
    run dynblk_available
    [ "$status" -ne 0 ]
    run vmdk_available
    [ "$status" -ne 0 ]

    set_secure_boot 0
    run secure_boot_enabled
    [ "$status" -ne 0 ]
    dynblk_available
    vmdk_available
}

@test "DynBlk codec probe requires registered compression providers" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_PROC_CRYPTO="$WORK/proc-crypto"
    cat >"$MINIOS_PROC_CRYPTO" <<'EOF'
name         : lzo
type         : compression

name         : deflate
type         : scomp

name         : zstd
type         : compression
EOF
    modprobe() {
        [ "$1" != -q ] || shift
        case "$1" in
        crypto-lz4)
            cat >>"$MINIOS_PROC_CRYPTO" <<'EOF'
name         : lz4
type         : compression
EOF
            return 0
            ;;
        *) return 1 ;;
        esac
    }

    dynblk_codec_available none
    dynblk_codec_available lzo
    dynblk_codec_available zstd
    dynblk_codec_available lz4
    run dynblk_codec_available deflate
    [ "$status" -ne 0 ]
    run dynblk_codec_available 842
    [ "$status" -ne 0 ]
}

@test "layered LUKS capability rejects the old empty marker" {
    . "$LIB"
    marker="$WORK/crypt-marker"
    : >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    run luks_layer_available
    [ "$status" -ne 0 ]

    printf '%s\n' luks-layer-v1 >"$marker"
    luks_layer_available
}

@test "existing session encryption comes only from metadata" {
    . "$LIB"
    chandir="$WORK/metadata-encryption/changes"
    mkdir -p "$chandir/1"
    printf '%s\n' 'default=1' 'session_mode[1]=raw' >"$chandir/session.conf"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" resume resume raw false luks
    [ "$status" -eq 0 ]
    [ "$output" = '1 raw false none none' ]

    rm -f "$chandir/session.json"
    printf '%s\n' 'session_encryption[1]=luks' >>"$chandir/session.conf"
    run restore_perch_session /dev/test "$chandir" resume resume raw false none
    [ "$status" -eq 0 ]
    [ "$output" = '1 raw false luks none' ]
}

@test "unsupported encrypted session metadata fails closed" {
    . "$LIB"
    chandir="$WORK/invalid-encryption/changes"
    mkdir -p "$chandir/1"
    get_union_fs() { printf '%s\n' overlayfs; }
    PERCHSIZE=0

    for metadata in \
        'session_mode[1]=native|session_encryption[1]=luks' \
        'session_mode[1]=squashfs|session_encryption[1]=luks' \
        'session_mode[1]=raw|session_encryption[1]=unknown' \
        'session_mode[1]=luks'; do
        rm -f "$chandir/session.json"
        {
            printf '%s\n' 'default=1'
            printf '%s\n' "$metadata" | tr '|' '\n'
        } >"$chandir/session.conf"
        run restore_perch_session /dev/test "$chandir" resume resume '' false none
        [ "$status" -ne 0 ]
        [[ "$output" == *'unsupported persistence metadata'* ]]
    done
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

@test "dynblk creates and mounts a block device without a loop" {
    setup_dispatch dynblk ext4 64
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 64MiB --compression none --format dynblk --execute"
    assert_log "mke2fs -t ext4 -F -E nodiscard /dev/dynblk7"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
    ! grep -Fq 'mount -o loop' "$LOG"
    grep -Fqx 'session_mode[1]=dynblk' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'dynblk_device=/dev/dynblk7' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "unavailable dynblk request follows the standard native persistence route" {
    setup_dispatch dynblk ext4 64
    dynblk_available() { return 1; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "restore:new:native"
    assert_log "mount --bind $TEST_CHANDIR/1 $TEST_CHANGES"
    ! grep -Fq 'dynblk create ' "$LOG"
    grep -Fqx 'session_mode[1]=native' "$TEST_CHANDIR/session.conf"
}

@test "Secure Boot dynblk request falls back before modprobe or create" {
    setup_dispatch dynblk ext4 64
    set_secure_boot 1

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "restore:new:native"
    assert_log "mount --bind $TEST_CHANDIR/1 $TEST_CHANGES"
    ! grep -Fq 'dynblk create ' "$LOG"
    grep -Fqx 'session_mode[1]=native' "$TEST_CHANDIR/session.conf"
}

@test "auto-resume preserves an unavailable dynblk session and creates a native replacement" {
    setup_dispatch native ext4 64
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/volume000.db"
    dynblk_available() { return 1; }
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' resume ;;
        perchmode) printf '%s\n' '' ;;
        perchsize) printf '%s\n' 64 ;;
        perchcomp) printf '%s\n' none ;;
        *) return 0 ;;
        esac
    }
    restore_perch_session() {
        printf 'restore:%s:%s\n' "$4" "$5" >>"$MINIOS_TEST_LOG"
        if [ "$4" = resume ]; then
            printf '%s\n' '1 dynblk false'
        else
            mkdir -p "$TEST_CHANDIR/2"
            printf '%s\n' '2 native true'
        fi
    }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "restore:resume:"
    assert_log "restore:new:native"
    assert_log "mount --bind $TEST_CHANDIR/2 $TEST_CHANGES"
    [ -f "$TEST_CHANDIR/1/volume000.db" ]
    grep -Fqx 'session_mode[2]=native' "$TEST_CHANDIR/session.conf"
}

@test "dynblk automatic sizing caps at 16GiB when backing space is sufficient" {
    setup_dispatch dynblk ext4
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 33554432 0 33554432 0% /"; }
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' new ;;
        perchmode) printf '%s\n' dynblk ;;
        perchsize) printf '%s\n' '' ;;
        perchcomp) printf '%s\n' zstd ;;
        *) return 0 ;;
        esac
    }
    dynblk_codec_available() { [ "$1" = zstd ]; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 16384MiB --compression zstd --format dynblk --execute"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
}

@test "dynblk unavailable explicit compression fails before create" {
    setup_dispatch dynblk ext4 64
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' new ;;
        perchmode) printf '%s\n' dynblk ;;
        perchsize) printf '%s\n' 64 ;;
        perchcomp) printf '%s\n' zstd ;;
        *) return 0 ;;
        esac
    }
    dynblk_codec_available() { return 1; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    ! grep -Fq 'dynblk create ' "$LOG"
    grep -Fq "compression 'zstd' is unavailable" "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "dynblk automatic sizing keeps the reserve free on a small backing store" {
    setup_dispatch dynblk ext4 0
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 3145728 0 3145728 0% /"; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    # 3072 MiB available minus the 256 MiB default reserve.
    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 2816MiB --compression none --format dynblk --execute"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
}

@test "dynblk automatic sizing below the free-space reserve falls back to memory" {
    setup_dispatch dynblk ext4 0
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 1048576 917504 131072 88% /"; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    ! grep -Fq 'dynblk create ' "$LOG"
    ! grep -Fq 'mke2fs ' "$LOG"
    [ ! -d "$TEST_CHANDIR/1" ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'no space is available' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "dynblk create delegates the mapping budget on 512MiB-class RAM" {
    # These mocked tests check delegation, not actual driver memory usage.
    # Real low-memory admission is covered by submodules/dynblk/tests/vm/.
    printf '%s\n' 'MemTotal:        474112 kB' >"$MINIOS_PROC_MEMINFO"
    setup_dispatch dynblk ext4 16384

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 16384MiB --compression none --format dynblk --execute"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
}

@test "dynblk create delegates the mapping budget on 1GiB-class RAM" {
    printf '%s\n' 'MemTotal:        999424 kB' >"$MINIOS_PROC_MEMINFO"
    setup_dispatch dynblk ext4 32768

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 32768MiB --compression none --format dynblk --execute"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
}

@test "dynblk preserves explicit thin capacity without a shell map-budget warning" {
    printf '%s\n' 'MemTotal:        474112 kB' >"$MINIOS_PROC_MEMINFO"
    setup_dispatch dynblk ext4 32768

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 32768MiB --compression none --format dynblk --execute"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
    grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ ! -s "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
}

@test "dynblk resume without perchsize delegates the mapping budget and preserves capacity" {
    setup_dispatch dynblk ext4
    TEST_SIZE=""
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/volume000.db"
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk load $TEST_CHANDIR/1/volume000.db --format dynblk --execute"
    assert_log "e2fsck -p /dev/dynblk7"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
    ! grep -Eq '^dynblk (create|grow) ' "$LOG"
    ! grep -Fq 'resize2fs ' "$LOG"
}

@test "dynblk resume loads stored geometry and grows only when explicitly requested" {
    setup_dispatch dynblk ext4 96
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/volume000.db"
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk load $TEST_CHANDIR/1/volume000.db --format dynblk --execute"
    assert_log "e2fsck -p /dev/dynblk7"
    assert_log "dynblk grow /dev/dynblk7 96MiB --execute"
    assert_log "resize2fs -f /dev/dynblk7"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
}

@test "dynblk activation failure continues in memory and is published as failed" {
    setup_dispatch dynblk ext4 64
    make_mock dynblk 'test "$1" != create'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    ! grep -Fq 'mke2fs ' "$LOG"
    ! grep -Fq 'mount -o errors=remount-ro /dev/dynblk7' "$LOG"
    [ ! -f "$TEST_CHANDIR/session.conf" ] || ! grep -q '^default=' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
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

@test "new SquashFS selection reserves a numbered metadata directory" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/new-squashfs/changes"
    mkdir -p "$chandir"
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" new new squashfs

    [ "$status" -eq 0 ]
    [ "$output" = "1 squashfs true none none" ]
    [ -d "$chandir/1" ]
    [ ! -f "$chandir/session.conf" ]
    [ ! -f "$chandir/session.json" ]
}

@test "new SquashFS session starts as metadata-only generation zero" {
    setup_dispatch squashfs ext4

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    [ ! -e "$TEST_CHANDIR/1/changes.sb" ]
    grep -Fqx 'session_mode[1]=squashfs' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'session_policy[1]=shutdown' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'session_generation[1]=0' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'session_union[1]=overlayfs' "$TEST_CHANDIR/session.conf"
    ! grep -Fq 'session_digest[1]=' "$TEST_CHANDIR/session.conf"
    ! grep -Fq 'session_compressed[1]=' "$TEST_CHANDIR/session.conf"
    ! grep -Fq 'session_footprint[1]=' "$TEST_CHANDIR/session.conf"
    assert_log "truncate -s 67108864 $WORK/squashfs-ext4/.minios-upper-1.ext4"
    [ "$MINIOS_SQUASHFS_POLICY" = shutdown ]
}

@test "SquashFS generation zero rejects an unexpected snapshot artifact" {
    setup_dispatch squashfs ext4
    mkdir -p "$TEST_CHANDIR/1"
    printf '%s\n' 'session_mode[1]=squashfs' 'session_policy[1]=shutdown' \
        'session_generation[1]=0' 'session_union[1]=overlayfs' \
        >"$TEST_CHANDIR/session.conf"
    : >"$TEST_CHANDIR/1/changes.sb"

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'could not be restored; continuing in memory' \
        "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "LiveKit DynFileFS dispatches to its existing container helper" {
    setup_dispatch dynfilefs ext4
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
}

@test "unknown persistence mode retains native to DynFileFS compatibility on FAT" {
    setup_dispatch legacy-fat vfat
    dynblk_available() { return 1; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
}

@test "native fallback prefers DynBlk on non-POSIX filesystems" {
    for fs in vfat exfat ntfs3 ntfs-3g; do
        setup_dispatch native "$fs"
        persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

        assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 64MiB --compression none --format dynblk --execute"
        assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
        grep -Fqx 'session_mode[1]=dynblk' "$TEST_CHANDIR/session.conf"
        ! grep -Fq '@mount.dynfilefs ' "$LOG"
        [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
    done
}

@test "native fallback uses DynFileFS when DynBlk is unavailable" {
    for fs in vfat exfat ntfs3 ntfs-3g; do
        setup_dispatch native "$fs"
        dynblk_available() { return 1; }
        persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

        assert_log "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
        grep -Fqx 'session_mode[1]=dynfilefs' "$TEST_CHANDIR/session.conf"
        ! grep -Fq 'dynblk create ' "$LOG"
        [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
    done
}

@test "native fallback uses DynFileFS under Secure Boot" {
    set_secure_boot 1
    for fs in vfat exfat ntfs3 ntfs-3g; do
        setup_dispatch native "$fs"
        persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

        assert_log "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
        grep -Fqx 'session_mode[1]=dynfilefs' "$TEST_CHANDIR/session.conf"
        ! grep -Fq 'dynblk create ' "$LOG"
        [ ! -e "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings" ]
    done
}

@test "failed POSIX probe falls back to DynBlk when available" {
    setup_dispatch native ext4
    make_mock ln 'exit 1'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 64MiB --compression none --format dynblk --execute"
    grep -Fqx 'session_mode[1]=dynblk' "$TEST_CHANDIR/session.conf"
    grep -Fq 'Native mode failed, falling back to DynBlk.' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    ! grep -Fq '@mount.dynfilefs ' "$LOG"
}

@test "failed POSIX probe falls back to DynFileFS when DynBlk is unavailable" {
    setup_dispatch native ext4
    dynblk_available() { return 1; }
    make_mock ln 'exit 1'
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000 -s 64"
    grep -Fqx 'session_mode[1]=dynfilefs' "$TEST_CHANDIR/session.conf"
    grep -Fq 'Native mode failed, falling back to DynFileFS.' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
    ! grep -Fq 'dynblk create ' "$LOG"
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

@test "union module loader falls back from legacy aufs to aufs-ng" {
    # shellcheck source=/dev/null
    . "$LIB"
    log="$WORK/aufs-modprobe.log"
    aufs_loaded=false
    debug_log() { :; }
    cmdline_value() { :; }
    refresh_devs() { :; }
    aufs_is_supported() { "$aufs_loaded"; }
    modprobe() {
        printf '%s\n' "$1" >>"$log"
        if [ "$1" = aufs-ng ]; then
            aufs_loaded=true
            return 0
        fi
        return 1
    }

    init_union_modules

    [ "$(sed -n '1p' "$log")" = aufs ]
    [ "$(sed -n '2p' "$log")" = aufs-ng ]
    [ "$(wc -l <"$log")" -eq 2 ]
    [ "$(get_union_fs)" = aufs ]
}

@test "Secure Boot never probes aufs-ng and falls back to OverlayFS" {
    # shellcheck source=/dev/null
    . "$LIB"
    set_secure_boot 1
    log="$WORK/secure-aufs-modprobe.log"
    debug_log() { :; }
    cmdline_value() { :; }
    refresh_devs() { :; }
    aufs_is_supported() { return 1; }
    modprobe() {
        printf '%s\n' "$1" >>"$log"
        [ "$1" = overlay ]
    }

    init_union_modules

    grep -Fqx overlay "$log"
    ! grep -Fqx aufs "$log"
    ! grep -Fqx aufs-ng "$log"
}

@test "Secure Boot refuses an already loaded aufs-ng union" {
    # shellcheck source=/dev/null
    . "$LIB"
    set_secure_boot 1
    export MINIOS_SYS_MODULE="$WORK/sys/module"
    mkdir -p "$MINIOS_SYS_MODULE/aufs_ng"
    aufs_is_supported() { return 0; }
    cmdline_value() { [ "$1" = union ] && printf '%s\n' aufs; }

    [ "$(get_union_fs)" = overlayfs ]
}

@test "AUFS mount options distinguish classic AUFS from aufs-ng" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_SYS_MODULE="$WORK/sys/module"
    log="$WORK/aufs-mount.log"
    mkdir -p "$MINIOS_SYS_MODULE"
    mount() { printf '%s\n' "$*" >>"$log"; }

    mount_aufs_union /memory/classic /union
    mkdir -p "$MINIOS_SYS_MODULE/aufs_ng"
    mount_aufs_union /memory/ng /union

    [ "$(sed -n '1p' "$log")" = \
        '-t aufs -o xino=/.xino,trunc_xino,br=/memory/classic aufs /union' ]
    [ "$(sed -n '2p' "$log")" = \
        '-t aufs -o xino=/.xino,br:/memory/ng=rw aufs /union' ]
}

@test "aufs-ng runtime union removes only visible OverlayFS whiteout devices" {
    # shellcheck source=/dev/null
    . "$LIB"
    log="$WORK/removed-whiteouts.log"
    get_union_fs() { printf '%s\n' aufs; }
    aufs_ng_is_loaded() { return 0; }
    find() {
        printf '%s\n' /union/etc/removed /union/dev/console
    }
    stat() {
        case "$3" in
        /union/etc/removed) printf '%s\n' 0:0 ;;
        /union/dev/console) printf '%s\n' 5:1 ;;
        *) return 1 ;;
        esac
    }
    rm() {
        case "${!#}" in
        /union/*) printf '%s\n' "${!#}" >>"$log" ;;
        *) /bin/rm "$@" ;;
        esac
    }

    normalize_module_whiteouts /union

    [ "$(cat "$log")" = /union/etc/removed ]
}

@test "aufs-ng runtime union removes an unstatable whiteout shadowing a lower symlink" {
    # shellcheck source=/dev/null
    . "$LIB"
    log="$WORK/removed-shadow.log"
    get_union_fs() { printf '%s\n' aufs; }
    aufs_ng_is_loaded() { return 0; }
    find() { printf '%s\n' /union/etc/rc0.d/K02eudev; }
    stat() { return 1; }
    rm() {
        case "${!#}" in
        /union/*) printf '%s\n' "${!#}" >>"$log" ;;
        *) /bin/rm "$@" ;;
        esac
    }

    normalize_module_whiteouts /union

    [ "$(cat "$log")" = /union/etc/rc0.d/K02eudev ]
}

@test "AUFS inventory and whiteout scans propagate enumeration failures" {
    # shellcheck source=/dev/null
    . "$LIB"
    get_union_fs() { printf '%s\n' aufs; }
    aufs_ng_is_loaded() { return 0; }
    active="/tmp/minios-aufs-active-branches.$$"
    /bin/rm -f "$active"
    find() { return 1; }

    ! normalize_module_whiteouts /union
    ! publish_union_branch_inventory /changes /bundles

    printf '%s\n' /bundles/00-core.sb >"$active"
    sort() { return 1; }
    ! publish_union_branch_inventory /changes /bundles
    /bin/rm -f "$active"
}

@test "AUFS inventory keeps its private umask scoped" {
    # shellcheck source=/dev/null
    . "$LIB"
    get_union_fs() { printf '%s\n' aufs; }
    inventory="$WORK/aufs-branches"
    active="/tmp/minios-aufs-active-branches.$$"
    printf '%s\n' /bundles/00-core.sb /bundles/01-kernel.sb >"$active"
    umask 022

    publish_union_branch_inventory /changes /bundles "$inventory"

    [ "$(umask)" = 0022 ]
    [ "$(stat -c %a "$inventory")" = 644 ]
    grep -Fqx '/changes=rw' "$inventory"
    grep -Fqx '/bundles/01-kernel.sb=rr+wh' "$inventory"
    /bin/rm -f "$active"
}

@test "AUFS runtime inventory is rootless-readable with a stable lock" {
    # shellcheck source=/dev/null
    . "$LIB"
    source_inventory="$WORK/source-aufs-branches"
    runtime_root="$WORK/runtime-root"
    printf '%s\n' '/changes=rw' '/bundles/00-core.sb=rr+wh' >"$source_inventory"
    chmod 0600 "$source_inventory"

    install_aufs_runtime_inventory "$runtime_root" "$source_inventory"

    runtime_inventory="$runtime_root/run/initramfs/minios-aufs-branches"
    runtime_lock="$runtime_root/run/initramfs/minios-aufs-branches.lock"
    [ "$(stat -c %a "$runtime_inventory")" = 644 ]
    [ "$(stat -c %a "$runtime_lock")" = 644 ]
    cmp "$source_inventory" "$runtime_inventory"
}

@test "classic AUFS keeps module whiteout devices untouched" {
    # shellcheck source=/dev/null
    . "$LIB"
    get_union_fs() { printf '%s\n' aufs; }
    aufs_ng_is_loaded() { return 1; }
    find() { return 1; }

    normalize_module_whiteouts /union
}

@test "OverlayFS runtime keeps native module whiteouts untouched" {
    # shellcheck source=/dev/null
    . "$LIB"
    get_union_fs() { printf '%s\n' overlayfs; }
    find() { return 1; }

    normalize_module_whiteouts /union
}

@test "unavailable Raw LUKS layer continues without unencrypted persistence" {
    setup_dispatch raw vfat 64 luks
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    ! grep -Fq 'restore:new:native' "$LOG"
    ! grep -Fq '@mount.dynfilefs' "$LOG"
    ! grep -Fq 'mount --bind' "$LOG"
    [ ! -f "$TEST_CHANDIR/session.conf" ] || ! grep -q '^default=' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    ! grep -Fqx 'boot_level=ok' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'persistence' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
}

@test "Raw LUKS creates changes.img through an owned loop and publishes ownership" {
    setup_dispatch raw ext4 64 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n%s\n' secret-pass secret-pass >"$MINIOS_PERSISTENCE_TTY"
    make_mock stty
    make_mock losetup 'case "$1" in --find) printf "%s\n" /dev/loop7 ;; esac'
    luks_mapper_ready() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    assert_log "losetup --find --show -- $TEST_CHANDIR/1/changes.img"
    assert_log 'cryptsetup luksFormat --type luks2 --batch-mode --key-file - /dev/loop7'
    assert_log 'cryptsetup open --type luks --key-file - /dev/loop7 minios-perch-1'
    assert_log "mke2fs -t ext4 -F /dev/mapper/minios-perch-1"
    grep -Fqx 'session_mode[1]=raw' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'session_encryption[1]=luks' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'encryption=luks' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'crypt_mapper=minios-perch-1' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'loop_device=/dev/loop7' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    ! grep -Fq secret-pass "$LOG"
}

@test "Raw LUKS rejects three wrong passwords without plaintext fallback" {
    setup_dispatch raw ext4 64 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n%s\n%s\n' wrong-one wrong-two wrong-three >"$MINIOS_PERSISTENCE_TTY"
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/changes.img"
    printf '%s\n' 'default=1' 'session_mode[1]=raw' \
        'session_encryption[1]=luks' >"$TEST_CHANDIR/session.conf"
    make_mock stty
    make_mock losetup 'case "$1" in --find) printf "%s\n" /dev/loop8 ;; esac'
    make_mock cryptsetup 'case "$1" in open) exit 1 ;; esac'
    fatal() { printf 'fatal:%s\n' "$*" >>"$MINIOS_TEST_LOG"; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    [ "$(grep -Fc 'cryptsetup open --type luks --key-file - /dev/loop8 minios-perch-1' "$LOG")" -eq 3 ]
    assert_log 'losetup --detach /dev/loop8'
    assert_log 'fatal:Incorrect password for encrypted persistence session #1'
    ! grep -Fq 'mount -o loop,errors=remount-ro' "$LOG"
    ! grep -Fq '@mount.dynfilefs' "$LOG"
    ! grep -Fq wrong- "$LOG"
}

@test "DynFileFS LUKS stacks FUSE loop mapper and ext4 ownership" {
    setup_dispatch dynfilefs vfat 8000 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n%s\n' secret-pass secret-pass >"$MINIOS_PERSISTENCE_TTY"
    make_mock stty
    make_mock umount
    make_mock losetup 'case "$1" in --find) printf "%s\n" /dev/loop9 ;; esac'
    luks_mapper_ready() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    assert_log "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000 -s 8000"
    assert_log "losetup --find --show -- $TEST_CHANGES/virtual.dat"
    assert_log 'cryptsetup luksFormat --type luks2 --batch-mode --key-file - /dev/loop9'
    assert_log "mount -o errors=remount-ro /dev/mapper/minios-perch-1 $TEST_CHANGES"
    grep -Fqx 'session_mode[1]=dynfilefs' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'session_encryption[1]=luks' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'loop_device=/dev/loop9' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "DynBlk LUKS uses its block device directly and disables compression" {
    setup_dispatch dynblk ext4 64 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n%s\n' secret-pass secret-pass >"$MINIOS_PERSISTENCE_TTY"
    make_mock stty
    luks_mapper_ready() { return 0; }
    cmdline_value() {
        case "$1" in
        perchdir) printf '%s\n' new ;;
        perchmode) printf '%s\n' dynblk ;;
        perchsize) printf '%s\n' 64 ;;
        perchencrypt) printf '%s\n' luks ;;
        perchcomp) printf '%s\n' zstd ;;
        *) return 0 ;;
        esac
    }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"

    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 64MiB --compression none --format dynblk --execute"
    assert_log 'cryptsetup luksFormat --type luks2 --batch-mode --key-file - /dev/dynblk7'
    assert_log 'mke2fs -t ext4 -F -E nodiscard /dev/mapper/minios-perch-1'
    assert_log "mount -o errors=remount-ro /dev/mapper/minios-perch-1 $TEST_CHANGES"
    ! grep -Fq 'losetup ' "$LOG"
    grep -Fqx 'dynblk_device=/dev/dynblk7' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'loop_device=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "DynBlk LUKS authenticates before backend growth and reopens the mapper" {
    setup_dispatch dynblk ext4 128 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n' secret-pass >"$MINIOS_PERSISTENCE_TTY"
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/volume000.db"
    printf '%s\n' 'default=1' 'session_mode[1]=dynblk' \
        'session_encryption[1]=luks' >"$TEST_CHANDIR/session.conf"
    make_mock stty
    luks_mapper_ready() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "dynblk load $TEST_CHANDIR/1/volume000.db --format dynblk --execute"
    open_line=$(grep -Fn 'cryptsetup open --type luks --key-file - /dev/dynblk7 minios-perch-1' "$LOG" | head -n 1 | cut -d: -f1)
    close_line=$(grep -Fn 'cryptsetup close minios-perch-1' "$LOG" | head -n 1 | cut -d: -f1)
    grow_line=$(grep -Fn 'dynblk grow /dev/dynblk7 128MiB --execute' "$LOG" | head -n 1 | cut -d: -f1)
    reopen_line=$(grep -Fn 'cryptsetup open --type luks --key-file - /dev/dynblk7 minios-perch-1' "$LOG" | tail -n 1 | cut -d: -f1)
    [ "$open_line" -lt "$close_line" ]
    [ "$close_line" -lt "$grow_line" ]
    [ "$grow_line" -lt "$reopen_line" ]
    assert_log 'resize2fs -f /dev/mapper/minios-perch-1'
}

@test "DynFileFS LUKS authenticates before virtual growth and reopens its loop" {
    setup_dispatch dynfilefs vfat 128 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n' secret-pass >"$MINIOS_PERSISTENCE_TTY"
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/changes.dat"
    printf '%s\n' 'default=1' 'session_mode[1]=dynfilefs' \
        'session_size[1]=64' 'session_encryption[1]=luks' >"$TEST_CHANDIR/session.conf"
    make_mock stty
    make_mock umount
    make_mock losetup 'case "$1" in --find) printf "%s\n" /dev/loop9 ;; esac'
    make_mock ls 'printf "%s\n" "-rw------- 1 0 0 67108864 Jan 1 00:00 $4"'
    luks_mapper_ready() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000"
    assert_log 'cryptsetup close minios-perch-1'
    assert_log 'losetup --detach /dev/loop9'
    assert_log "umount $TEST_CHANGES"
    assert_log "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000 -s 128"
    [ "$(grep -Fc 'losetup --find --show --' "$LOG")" -eq 2 ]
    [ "$(grep -Fc 'cryptsetup open --type luks --key-file - /dev/loop9 minios-perch-1' "$LOG")" -eq 2 ]
    assert_log 'resize2fs -f /dev/mapper/minios-perch-1'
}

@test "DynFileFS LUKS retries a busy backend while reopening after growth" {
    setup_dispatch dynfilefs vfat 128 luks
    marker="$WORK/crypt-marker"
    retry_state="$WORK/dynfilefs-retry"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n' secret-pass >"$MINIOS_PERSISTENCE_TTY"
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/changes.dat"
    printf '%s\n' 'default=1' 'session_mode[1]=dynfilefs' \
        'session_size[1]=64' 'session_encryption[1]=luks' >"$TEST_CHANDIR/session.conf"
    export retry_state
    make_mock stty
    make_mock umount
    make_mock sleep
    make_mock losetup 'case "$1" in --find) printf "%s\n" /dev/loop9 ;; esac'
    make_mock ls 'printf "%s\n" "-rw------- 1 0 0 67108864 Jan 1 00:00 $4"'
    make_mock @mount.dynfilefs '
mountpoint= has_size=false
while [ $# -gt 0 ]; do
    case "$1" in -m) mountpoint=$2; shift ;; -s) has_size=true; shift ;; esac
    shift
done
if [ "$has_size" = true ] && [ ! -e "$retry_state" ]; then
    : >"$retry_state"
    exit 1
fi
mkdir -p "$mountpoint"
: >"$mountpoint/virtual.dat"'
    luks_mapper_ready() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    [ "$(grep -Fc "@mount.dynfilefs -f $TEST_CHANDIR/1/changes.dat -m $TEST_CHANGES -p 4000 -s 128" "$LOG")" -eq 2 ]
    assert_log 'sleep 1'
    assert_log 'resize2fs -f /dev/mapper/minios-perch-1'
}

@test "Raw LUKS authenticates before backing-file growth and reopens its loop" {
    setup_dispatch raw ext4 128 luks
    marker="$WORK/crypt-marker"
    printf '%s\n' luks-layer-v1 >"$marker"
    MINIOS_CRYPT_MARKERS="$marker"
    MINIOS_PERSISTENCE_TTY="$WORK/tty"
    MINIOS_PERSISTENCE_TTY_OUTPUT=/dev/null
    printf '%s\n' secret-pass >"$MINIOS_PERSISTENCE_TTY"
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/changes.img"
    printf '%s\n' 'default=1' 'session_mode[1]=raw' \
        'session_size[1]=64' 'session_encryption[1]=luks' >"$TEST_CHANDIR/session.conf"
    make_mock stty
    make_mock losetup 'case "$1" in --find) printf "%s\n" /dev/loop9 ;; esac'
    make_mock ls 'printf "%s\n" "-rw------- 1 0 0 67108864 Jan 1 00:00 $4"'
    luks_mapper_ready() { return 0; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    assert_log 'cryptsetup close minios-perch-1'
    assert_log 'losetup --detach /dev/loop9'
    assert_log "truncate -s 128M $TEST_CHANDIR/1/changes.img"
    [ "$(grep -Fc "losetup --find --show -- $TEST_CHANDIR/1/changes.img" "$LOG")" -eq 2 ]
    [ "$(grep -Fc 'cryptsetup open --type luks --key-file - /dev/loop9 minios-perch-1' "$LOG")" -eq 2 ]
    assert_log 'resize2fs -f /dev/mapper/minios-perch-1'
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
    df() {
        [ "$1" = -P ] || return 1
        printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 10000000 5000000 4096000 55% /"
    }
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
    # 9000 MiB minus 256 MiB reserve, allowing 1/500 of data size for indexes.
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 8726"
}

@test "automatic DynFileFS sizing never grows past a small device" {
    setup_dispatch dynfilefs ext4 0
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 3145728 0 3145728 0% /"; }
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    # (3072 MiB - 256 MiB reserve) * 500 / 501, rounded down to whole MiB.
    assert_log "@mount.dynfilefs -f $TEST_DATA/changes/1/changes.dat -m $TEST_CHANGES -p 4000 -s 2810"
}

@test "new DynFileFS session with no available capacity falls back to memory" {
    setup_dispatch dynfilefs ext4 0
    df() { printf '%s\n' "Filesystem 1K-blocks Used Available Use% Mounted on" "/dev/test 1048576 1048576 0 100% /"; }

    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true

    ! grep -Fq '@mount.dynfilefs' "$LOG"
    [ ! -d "$TEST_CHANDIR/1" ]
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fq 'no space is available' "$MINIOS_PERSISTENCE_RUNDIR/boot-warnings"
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
    [ "$output" = "7 dynfilefs false none none" ]
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
    [ "$output" = "7 dynfilefs false none none" ]
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
    grep -Fqx 'dynblk_device=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'encryption=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'crypt_mapper=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'loop_device=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ "$(wc -l <"$MINIOS_PERSISTENCE_RUNDIR/boot-state")" -eq 13 ]
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

@test "post-union AUFS authority accepts a bind source for the writable branch" {
    # shellcheck source=/dev/null
    . "$LIB"
    changes="$WORK/changes"
    source="$WORK/session"
    union="$WORK/union"
    mkdir -p "$changes" "$source" "$union" "$MINIOS_SYS_FS_AUFS/si_test"
    printf '%s\n' "$source=rw" >"$MINIOS_SYS_FS_AUFS/si_test/br0"
    printf '%s\n' "none $union aufs rw,si=test 0 0" >"$MINIOS_PROC_MOUNTS"
    perch_store_identity() {
        case "$1" in
        "$changes" | "$source") printf '%s\n' '253 42' ;;
        *) return 1 ;;
        esac
    }

    perch_union_is_active "$union" "$changes"
}

@test "post-union aufs-ng authority verifies writes through the union" {
    # shellcheck source=/dev/null
    . "$LIB"
    changes="$WORK/changes"
    union="$WORK/union"
    mkdir -p "$changes"
    ln -s "$changes" "$union"
    printf '%s\n' "none $union aufs rw,si=1 0 0" >"$MINIOS_PROC_MOUNTS"
    aufs_ng_is_loaded() { return 0; }

    perch_union_is_active "$union" "$changes"

    run bash -c 'find "$1" -name ".minios-persistence-probe.*" -print -quit' _ "$changes"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
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
    active="/tmp/minios-aufs-active-branches.$$"
    grep -Fq "$bundles/01-core" "$active"
    ! grep -Fq "$bundles/02-broken" "$active"
    grep -Fq "$bundles/03-apps" "$active"
    rm -f "$active"
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

@test "Ventoy persistence resolves dm device when mapper symlink is absent" {
    # shellcheck source=/dev/null
    . "$LIB"
    mkdir -p "$MINIOS_VENTOY_DIR" "$MINIOS_SYS_CLASS_BLOCK/dm-1/dm" "$MINIOS_DEV_ROOT"
    printf '%s\n' '0 100 linear /dev/sda1 0' >"$MINIOS_VENTOY_DIR/ventoy_dm_table"
    printf '%s\n' sda1 >"$MINIOS_SYS_CLASS_BLOCK/dm-1/dm/name"
    : >"$MINIOS_DEV_ROOT/dm-1"
    blkid() { return 0; }
    lsblk() {
        case "$2" in
        pkname) printf '%s\n' sda ;;
        name) printf '%s\n' sda1 ;;
        esac
    }

    result=$(manage_perch_partition /dev/mapper/ventoy resume)

    [ "$result" = "$MINIOS_DEV_ROOT/dm-1/minios/changes" ]
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
    grep -Fqx 'dynblk_device=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    [ "$(wc -l <"$MINIOS_PERSISTENCE_RUNDIR/boot-state")" -eq 13 ]
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

@test "DynBlk setup offers only available compression codecs" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_MENU_TTY=/dev/null
    dynblk_available() { return 0; }
    vmdk_available() { return 1; }
    device_bestfs() { printf '%s\n' vfat; }
    luks_layer_available() { return 1; }
    dynblk_codec_available() {
        case "$1" in
        lz4 | zstd) return 0 ;;
        *) return 1 ;;
        esac
    }
    ncurses-menu() {
        local title="" file=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
            -t) shift; title="$1" ;;
            -f) shift; file="$1" ;;
            esac
            shift
        done
        case "$title" in
        'Select storage:') printf '%s\n' DynBlk >&2 ;;
        'Encryption:') printf '%s\n' None >&2 ;;
        'Compression:')
            cp "$file" "$WORK/compression-options"
            printf '%s\n' zstd >&2
            ;;
        *) return 1 ;;
        esac
    }

    run select_new_session_mode /dev/test

    [ "$status" -eq 0 ]
    [ "$output" = "dynblk none zstd" ]
    [ "$(cat "$WORK/compression-options")" = "$(printf '%s\n' None lz4 zstd)" ]
    ! grep -Fqx 842 "$WORK/compression-options"
}

@test "encrypted DynBlk setup skips compression selection" {
    # shellcheck source=/dev/null
    . "$LIB"
    export MINIOS_MENU_TTY=/dev/null
    dynblk_available() { return 0; }
    vmdk_available() { return 1; }
    device_bestfs() { printf '%s\n' vfat; }
    luks_layer_available() { return 0; }
    dynblk_codec_available() { return 0; }
    ncurses-menu() {
        local title=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
            -t) shift; title="$1" ;;
            esac
            shift
        done
        case "$title" in
        'Select storage:') printf '%s\n' DynBlk >&2 ;;
        'Encryption:') printf '%s\n' LUKS2 >&2 ;;
        'Compression:')
            : >"$WORK/compression-was-called"
            return 1
            ;;
        *) return 1 ;;
        esac
    }

    run select_new_session_mode /dev/test

    [ "$status" -eq 0 ]
    [ "$output" = "dynblk luks none" ]
    [ ! -e "$WORK/compression-was-called" ]
}

@test "setup carries selected DynBlk compression to creation state" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/setup-dynblk/changes"
    mkdir -p "$chandir"
    get_union_fs() { printf '%s\n' overlayfs; }
    select_new_session_mode() { printf '%s\n' 'dynblk none zstd'; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" setup setup "" false none none

    [ "$status" -eq 0 ]
    [ "$output" = "1 dynblk true none zstd" ]
    [ -d "$chandir/1" ]
}

@test "ask on an empty store enters setup and creates the selected backend" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/ask-empty/changes"
    mkdir -p "$chandir"
    get_union_fs() { printf '%s\n' overlayfs; }
    select_new_session_mode() { printf '%s\n' dynfilefs; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" ask ask "" false

    [ "$status" -eq 0 ]
    [ "$output" = "1 dynfilefs true none none" ]
    [ -d "$chandir/1" ]
}

@test "setup creates a new session with the interactively selected backend" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/setup-empty/changes"
    mkdir -p "$chandir"
    get_union_fs() { printf '%s\n' overlayfs; }
    select_new_session_mode() { printf '%s\n' raw; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" setup setup "" false

    [ "$status" -eq 0 ]
    [ "$output" = "1 raw true none none" ]
    [ -d "$chandir/1" ]
}

@test "new remains automatic and does not invoke setup selection" {
    # shellcheck source=/dev/null
    . "$LIB"
    chandir="$WORK/new-automatic/changes"
    mkdir -p "$chandir"
    get_union_fs() { printf '%s\n' overlayfs; }
    select_new_session_mode() { return 1; }
    PERCHSIZE=0

    run restore_perch_session /dev/test "$chandir" new new "" false

    [ "$status" -eq 0 ]
    [ "$output" = "1 native true none none" ]
    [ -d "$chandir/1" ]
}

@test "automatic new sessions keep native when DynBlk is unavailable" {
    . "$LIB"
    get_union_fs() { printf '%s\n' overlayfs; }
    dynblk_available() { return 1; }
    select_new_session_mode() { return 1; }
    PERCHSIZE=0

    for action in new resume; do
        chandir="$WORK/unavailable-$action/changes"
        mkdir -p "$chandir"
        run restore_perch_session /dev/test "$chandir" "$action" "$action" "" true
        [ "$status" -eq 0 ]
        [ "$output" = "1 native true none none" ]
        [ -d "$chandir/1" ]
    done
}

@test "automatic new sessions keep native under Secure Boot" {
    . "$LIB"
    set_secure_boot 1
    get_union_fs() { printf '%s\n' overlayfs; }
    select_new_session_mode() { return 1; }
    PERCHSIZE=0

    for action in new resume; do
        chandir="$WORK/secure-boot-$action/changes"
        mkdir -p "$chandir"
        run restore_perch_session /dev/test "$chandir" "$action" "$action" "" true
        [ "$status" -eq 0 ]
        [ "$output" = "1 native true none none" ]
        [ -d "$chandir/1" ]
    done
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
    [ "$output" = "1 native true none none" ]
    [ -d "$chandir/1" ]
}

@test "automatic default does not override an explicitly selected backend" {
    . "$LIB"
    get_union_fs() { printf '%s\n' overlayfs; }
    dynblk_available() { echo 'Unexpected automatic backend probe' >&2; return 1; }
    PERCHSIZE=0

    for mode in native raw dynfilefs dynblk vmdk squashfs; do
        chandir="$WORK/explicit-$mode/changes"
        mkdir -p "$chandir"
        run restore_perch_session /dev/test "$chandir" new new "$mode" false
        [ "$status" -eq 0 ]
        [ "$output" = "1 $mode true none none" ]
    done
}

@test "automatic resume preserves existing backend and legacy native sessions" {
    . "$LIB"
    get_union_fs() { printf '%s\n' overlayfs; }
    dynblk_available() { echo 'Unexpected automatic backend probe' >&2; return 1; }
    PERCHSIZE=0

    for mode in native raw dynfilefs dynblk vmdk squashfs legacy; do
        chandir="$WORK/resume-$mode/changes"
        mkdir -p "$chandir/1"
        printf '%s\n' 'default=1' >"$chandir/session.conf"
        expected=$mode
        if [ "$mode" = legacy ]; then
            expected=native
        else
            printf 'session_mode[1]=%s\n' "$mode" >>"$chandir/session.conf"
        fi
        run restore_perch_session /dev/test "$chandir" resume resume "" true
        [ "$status" -eq 0 ]
        [ "$output" = "1 $expected false none none" ]
        [ ! -d "$chandir/2" ]
    done
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
    [ "$(printf '%s\n' "$output" | tail -n 1)" = "2 native true none none" ]
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

    [ "$result" = "2 native true none none" ]
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

@test "dynblk explicit multi-terabyte size follows backend limits" {
    setup_dispatch dynblk ext4 4194304
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"
    assert_log "dynblk create $TEST_CHANDIR/1/volume000.db --size 4194304MiB --compression none --format dynblk --execute"
}

@test "VMDK creates split storage and publishes its own session mode" {
    setup_dispatch vmdk exfat 64
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    perch_state_commit "$WORK/union"
    assert_log "dynblk create $TEST_CHANDIR/1/volume.vmdk --size 64MiB --compression none --format vmdk --execute"
    assert_log "mount -o errors=remount-ro /dev/dynblk7 $TEST_CHANGES"
    grep -Fqx 'session_mode[1]=vmdk' "$TEST_CHANDIR/session.conf"
    grep -Fqx 'mode=vmdk' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'dynblk_device=/dev/dynblk7' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    ! grep -Eq '(reclaim|--compact|fstrim)' "$LOG"
}

@test "VMDK resumes its descriptor without creating a native container" {
    setup_dispatch vmdk ext4
    TEST_SIZE=""
    mkdir -p "$TEST_CHANDIR/1"
    : >"$TEST_CHANDIR/1/volume.vmdk"
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    assert_log "dynblk load $TEST_CHANDIR/1/volume.vmdk --format vmdk --execute"
    ! grep -Eq '^dynblk (create|grow) ' "$LOG"
    ! grep -Fq 'volume000.db' "$LOG"
}

@test "VMDK metadata cannot create an image over a native DynBlk session" {
    setup_dispatch vmdk ext4
    mkdir -p "$TEST_CHANDIR/1"
    printf '%s' 'existing native image' >"$TEST_CHANDIR/1/volume000.db"
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    ! grep -Eq '^dynblk (create|load|grow) ' "$LOG"
    [ "$(cat "$TEST_CHANDIR/1/volume000.db")" = 'existing native image' ]
    [ ! -e "$TEST_CHANDIR/1/volume.vmdk" ]
}

@test "VMDK cannot publish successful persistence with a missing block device" {
    setup_dispatch vmdk ext4 64
    persistent_changes "$TEST_DATA" "$TEST_CHANGES" || true
    dynblk_device_ready() { return 1; }
    run perch_state_commit "$WORK/union"
    grep -Fqx 'boot_level=failed' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
    grep -Fqx 'dynblk_device=none' "$MINIOS_PERSISTENCE_RUNDIR/boot-state"
}

@test "external-kernel boot displaces the installed active kernel without changing its marker" {
    # shellcheck source=/dev/null
    . "$LIB"
    debug_log() { :; }
    data="$WORK/mixed-kernel/minios"
    boot="$data/boot"
    mkdir -p "$boot"
    printf '%s\n' installed >"$boot/active-kernel"

    for version in installed external stale; do
        : >"$data/01-kernel-$version.sb"
        : >"$boot/vmlinuz-$version"
        : >"$boot/initrfs-$version.img"
    done
    get_running_kernel() { printf '%s\n' external; }

    setup_running_kernel "$data"

    [ ! -e "$data/01-kernel-installed.sb" ]
    [ ! -e "$boot/vmlinuz-installed" ]
    [ ! -e "$boot/initrfs-installed.img" ]
    [ -f "$data/kernels/installed/01-kernel-installed.sb" ]
    [ -f "$data/kernels/installed/vmlinuz-installed" ]
    [ -f "$data/kernels/installed/initrfs-installed.img" ]
    [ -f "$data/01-kernel-external.sb" ]
    [ -f "$boot/vmlinuz-external" ]
    [ -f "$boot/initrfs-external.img" ]
    [ ! -e "$data/01-kernel-stale.sb" ]
    [ -f "$data/kernels/stale/01-kernel-stale.sb" ]
    [ -f "$data/kernels/stale/vmlinuz-stale" ]
    [ -f "$data/kernels/stale/initrfs-stale.img" ]
    [ "$(cat "$boot/active-kernel")" = installed ]
}
