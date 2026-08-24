#!/usr/bin/env bats

@test "real bounded SquashFS extraction preserves hardlinks symlinks and user xattrs" {
    [ "$(id -u)" -eq 0 ] || skip "root privileges are required"
    losetup --find >/dev/null 2>&1 || skip "a free loop device is required"
    command -v python3 >/dev/null || skip "python3 is required for xattr verification"
    ROOT=$(CDPATH='' cd -- "$BATS_TEST_DIRNAME/.." && pwd)

    run "$ROOT/tests/squashfs_activation_integration.sh" "$ROOT"

    [ "$status" -eq 0 ]
}
