#!/usr/bin/env bats

setup() {
    LIVE_ROOT="${BATS_TEST_DIRNAME}/.."
    functions="${BATS_TEST_TMPDIR}/functions"
    awk '/^check_package\(\)/,/^}/' "${LIVE_ROOT}/condinapt" >"${functions}"
}

@test "CondinAPT matches exact madison versions with Bionic mawk-compatible whitespace" {
    run env FUNCTIONS="$functions" bash -c '
        . "$FUNCTIONS"
        CHECK_ONLY=false VERBOSITY_LEVEL=0
        pkg_is_installed() { return 1; }
        apt-cache() {
            printf "driver | 2.0-1 | https://example.invalid main Packages\n"
            printf "driver |\t1:1.2~git.abc-0kali1+minios2 \t| https://example.invalid contrib Packages\n"
        }
        check_package driver "1:1.2~git.abc-0kali1+minios2" true
        [ "$FOUND_EXACT_VERSION" = true ]
    '
    [ "$status" -eq 0 ]
}

@test "CondinAPT does not accept a regex-like near match as an exact version" {
    run env FUNCTIONS="$functions" bash -c '
        . "$FUNCTIONS"
        CHECK_ONLY=false VERBOSITY_LEVEL=0
        pkg_is_installed() { return 1; }
        apt-cache() { printf "driver | 1x2-1 | https://example.invalid main Packages\n"; }
        check_package driver "1.2-1" true
        rc=$?
        [ "$rc" = 1 ] && [ "$FOUND_EXACT_VERSION" = false ]
    '
    [ "$status" -eq 0 ]
}
