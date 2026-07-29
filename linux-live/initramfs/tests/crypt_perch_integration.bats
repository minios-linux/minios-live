#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    MINIOS_MKE2FS="${MINIOS_MKE2FS:-$ROOT/livekit-mos/bin/mke2fs}"
    MINIOS_E2FSCK="${MINIOS_E2FSCK:-$ROOT/livekit-mos/bin/e2fsck}"
    MINIOS_RESIZE2FS="${MINIOS_RESIZE2FS:-$ROOT/livekit-mos/bin/resize2fs}"
    MINIOS_CRYPT_ROOT="${MINIOS_CRYPT_ROOT:-$ROOT/livekit-mos}"
    CRYPT_LIBS="$MINIOS_CRYPT_ROOT/lib:$MINIOS_CRYPT_ROOT/usr/lib"
    CRYPT_TOOL_SOURCE=system
    USE_BUNDLED_CRYPT=0
    WORKDIR=""
    MOUNTPOINT=""
    MAPPER="minios-perch-test-$$"
    LOOP=""

    if [ -x "$MINIOS_CRYPT_ROOT/lib/libc.so" ] &&
        [ -x "$MINIOS_CRYPT_ROOT/usr/sbin/cryptsetup" ] &&
        [ -x "$MINIOS_CRYPT_ROOT/usr/sbin/dmsetup" ] &&
        [ -x "$MINIOS_CRYPT_ROOT/sbin/losetup" ]; then
        CRYPT_TOOL_SOURCE=bundled
        USE_BUNDLED_CRYPT=1
    fi
}

teardown() {
    if [ -n "$MOUNTPOINT" ] && mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
        umount "$MOUNTPOINT" 2>/dev/null || true
    fi
    [ ! -b "/dev/mapper/$MAPPER" ] || cryptsetup_cmd close "$MAPPER" 2>/dev/null || true
    [ -z "$LOOP" ] || losetup_cmd -d "$LOOP" 2>/dev/null || true
    [ -z "$WORKDIR" ] || rm -rf "$WORKDIR"
}

skip_or_fail() {
    if [ "${MINIOS_REQUIRE_CRYPT_TEST:-0}" = 1 ]; then
        printf 'FAIL: %s\n' "$1" >&2
        return 1
    fi
    skip "$1"
}

cryptsetup_cmd() {
    if [ "$USE_BUNDLED_CRYPT" = 1 ]; then
        "$MINIOS_CRYPT_ROOT/lib/libc.so" --library-path "$CRYPT_LIBS" \
            "$MINIOS_CRYPT_ROOT/usr/sbin/cryptsetup" "$@"
    else
        command cryptsetup "$@"
    fi
}

dmsetup_cmd() {
    if [ "$USE_BUNDLED_CRYPT" = 1 ]; then
        "$MINIOS_CRYPT_ROOT/lib/libc.so" --library-path "$CRYPT_LIBS" \
            "$MINIOS_CRYPT_ROOT/usr/sbin/dmsetup" "$@"
    else
        command dmsetup "$@"
    fi
}

losetup_cmd() {
    if [ "$USE_BUNDLED_CRYPT" = 1 ]; then
        "$MINIOS_CRYPT_ROOT/lib/libc.so" --library-path "$CRYPT_LIBS" \
            "$MINIOS_CRYPT_ROOT/sbin/losetup" "$@"
    else
        command losetup "$@"
    fi
}

@test "LUKS persistence container grows and retains data" {
    [ "$(id -u)" -eq 0 ] || { skip_or_fail "root privileges are required"; return; }
    for tool in mount umount mountpoint truncate; do
        command -v "$tool" >/dev/null 2>&1 || { skip_or_fail "$tool is unavailable"; return; }
    done
    if [ "$USE_BUNDLED_CRYPT" != 1 ]; then
        for tool in cryptsetup dmsetup losetup; do
            command -v "$tool" >/dev/null 2>&1 || { skip_or_fail "$tool is unavailable"; return; }
        done
    fi
    for tool in "$MINIOS_MKE2FS" "$MINIOS_E2FSCK" "$MINIOS_RESIZE2FS"; do
        [ -x "$tool" ] || { skip_or_fail "initrd binary is unavailable: $tool"; return; }
    done
    losetup_cmd --find >/dev/null 2>&1 || { skip_or_fail "no free loop device is available"; return; }
    dmsetup_cmd version >/dev/null 2>&1 || { skip_or_fail "device-mapper is unavailable"; return; }

    WORKDIR=$(mktemp -d)
    CONTAINER="$WORKDIR/changes.luks"
    MOUNTPOINT="$WORKDIR/mount"
    mkdir -p "$MOUNTPOINT"

    truncate -s 64M "$CONTAINER"
    LOOP=$(losetup_cmd --find --show "$CONTAINER")
    printf '%s' minios-test-passphrase | cryptsetup_cmd luksFormat --type luks2 --batch-mode --key-file - "$LOOP"
    printf '%s' minios-test-passphrase | cryptsetup_cmd open --key-file - "$LOOP" "$MAPPER"
    "$MINIOS_MKE2FS" -q -t ext4 -F "/dev/mapper/$MAPPER"
    mount "/dev/mapper/$MAPPER" "$MOUNTPOINT"
    printf '%s\n' persistent-data >"$MOUNTPOINT/persistence-test"
    sync
    umount "$MOUNTPOINT"
    cryptsetup_cmd close "$MAPPER"
    losetup_cmd -d "$LOOP"
    LOOP=""

    truncate -s 96M "$CONTAINER"
    LOOP=$(losetup_cmd --find --show "$CONTAINER")
    printf '%s' minios-test-passphrase | cryptsetup_cmd open --key-file - "$LOOP" "$MAPPER"
    printf '%s' minios-test-passphrase | cryptsetup_cmd resize --key-file - "$MAPPER"
    run "$MINIOS_E2FSCK" -f -p "/dev/mapper/$MAPPER"
    [ "$status" -le 1 ]
    "$MINIOS_RESIZE2FS" "/dev/mapper/$MAPPER"
    mount "/dev/mapper/$MAPPER" "$MOUNTPOINT"
    grep -qx persistent-data "$MOUNTPOINT/persistence-test"

    printf 'LUKS integration test passed (%s crypto tools)\n' "$CRYPT_TOOL_SOURCE"
}
