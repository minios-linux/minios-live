#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH='' cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    WORK=$(mktemp -d)
    WRAPPER="$WORK/dracut-install"
    export INSTALL_TRACE="$WORK/arguments" INSTALL_STATUS=0
    # Exercise the actual wrapper embedded in mkdracut, not a test copy.
    awk '
        index($0, "cat >\"$DRACUT_INSTALL\"") { body = 1; next }
        body && /^EOF$/ { exit }
        body { print }
    ' "$ROOT/dracut-mos/mkdracut" >"$WRAPPER"
    [ -s "$WRAPPER" ]
    cat >"$WRAPPER.minios-real" <<'EOF'
#!/bin/bash
printf '<%s>\n' "$@" >"$INSTALL_TRACE"
exit "$INSTALL_STATUS"
EOF
    chmod +x "$WRAPPER" "$WRAPPER.minios-real"
}

teardown() {
    rm -rf "$WORK"
}

assert_forwarded() {
    [ -f "$INSTALL_TRACE" ]
    [ "$(cat "$INSTALL_TRACE")" = "$(printf '<%s>\n' "$@")" ]
}

@test "built-in crc32c alone succeeds without invoking the installer" {
    run "$WRAPPER" -D "$WORK/root" --kerneldir /lib/modules/test/ -o -m crc32c
    [ "$status" -eq 0 ]
    [ ! -e "$INSTALL_TRACE" ]
}

@test "built-in-only requests support repeated operands and trailing flags" {
    run "$WRAPPER" -D "$WORK/root" --module crc32c crc32c -o --silent
    [ "$status" -eq 0 ]
    [ ! -e "$INSTALL_TRACE" ]
}

@test "mixed requests preserve other modules and argument boundaries" {
    run "$WRAPPER" -D "$WORK/root path" -m crc32c ext4 '=drivers/usb' crc32c
    [ "$status" -eq 0 ]
    assert_forwarded -D "$WORK/root path" -m ext4 '=drivers/usb'
}

@test "real installer failures propagate after filtering" {
    run env INSTALL_STATUS=23 "$WRAPPER" -D "$WORK/root" -m crc32c nonexistent_module
    [ "$status" -eq 23 ]
    assert_forwarded -D "$WORK/root" -m nonexistent_module
}

@test "file installation never filters a filename called crc32c" {
    run "$WRAPPER" -D "$WORK/root" crc32c /lib/crc32c
    [ "$status" -eq 0 ]
    assert_forwarded -D "$WORK/root" crc32c /lib/crc32c
}

@test "option values called crc32c are retained before and after module mode" {
    run "$WRAPPER" -D crc32c -m crc32c ext4 -N crc32c --kerneldir crc32c
    [ "$status" -eq 0 ]
    assert_forwarded -D crc32c -m ext4 -N crc32c --kerneldir crc32c
}

@test "attached option values do not count as remaining modules" {
    run "$WRAPPER" -Dcrc32c --kerneldir=crc32c -m crc32c --mod-filter-noname=crc32c
    [ "$status" -eq 0 ]
    [ ! -e "$INSTALL_TRACE" ]
}

@test "an originally empty module request still reaches the installer" {
    run env INSTALL_STATUS=1 "$WRAPPER" -D "$WORK/root" -o -m
    [ "$status" -eq 1 ]
    assert_forwarded -D "$WORK/root" -o -m
}

@test "unknown options are delegated unchanged instead of hiding errors" {
    run env INSTALL_STATUS=2 "$WRAPPER" -m crc32c --mod-filter-unknown=crc32c
    [ "$status" -eq 2 ]
    assert_forwarded -m crc32c --mod-filter-unknown=crc32c
}

@test "missing option values are delegated unchanged" {
    run env INSTALL_STATUS=2 "$WRAPPER" -m crc32c --kerneldir
    [ "$status" -eq 2 ]
    assert_forwarded -m crc32c --kerneldir
}

@test "module operands before the mode flag and after double dash are handled" {
    run "$WRAPPER" crc32c ext4 --module -- crc32c '=drivers/usb'
    [ "$status" -eq 0 ]
    assert_forwarded ext4 --module -- '=drivers/usb'
}

@test "a mode flag used as an option value does not enable filtering" {
    run "$WRAPPER" -D "$WORK/root" -N -m crc32c /lib/crc32c
    [ "$status" -eq 0 ]
    assert_forwarded -D "$WORK/root" -N -m crc32c /lib/crc32c
}
