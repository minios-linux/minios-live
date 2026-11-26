#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
    PROGRAM="$ROOT/livekit-mos/bin/mc"
    export LC_ALL=C
}

@test "Mini Commander initrd payload is a static 32-bit executable" {
    [ -x "$PROGRAM" ]
    run file "$PROGRAM"
    [ "$status" -eq 0 ]
    [[ "$output" == *'ELF 32-bit'* ]]
    [[ "$output" == *'Intel i386'* ]]
    [[ "$output" == *'statically linked'* ]]
    run readelf -l "$PROGRAM"
    [ "$status" -eq 0 ]
    [[ "$output" != *'INTERP'* ]]
    run readelf -d "$PROGRAM"
    [ "$status" -eq 0 ]
    [[ "$output" != *'(NEEDED)'* ]]
}

@test "Mini Commander accepts independent panel paths without starting the UI" {
    run "$PROGRAM" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *'left-directory [right-directory]'* ]]
}

@test "both initrd builders keep mc and its Linux console description" {
    grep -Fxq '    bin/mc' "$ROOT/livekit-mos/mkinitrfs"
    grep -Fq 'inst_simple "$STATIC_BIN/mc" "/bin/mc"' \
        "$ROOT/dracut-mos/90minios/module-setup.sh"
    [ -s "$ROOT/livekit-mos/usr/share/terminfo/l/linux" ]
}
