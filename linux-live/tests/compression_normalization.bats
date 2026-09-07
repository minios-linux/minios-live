#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_TMPDIR}/root"
    INFO="${BATS_TEST_TMPDIR}/info"
    mkdir -p "${ROOT}" "${INFO}"
    MINIOSLIB="${BATS_TEST_DIRNAME}/../minioslib"
}

run_normalizer() {
    local dir="$1" suffix="$2"
    run env VERBOSITY_LEVEL=1 DPKG_INFO_DIR="${INFO}" \
        bash -c '. "$1"; normalize_package_compressed_files "$2" "$3"' \
        _ "${MINIOSLIB}" "${dir}" "${suffix}"
    [ "${status}" -eq 0 ]
}

@test "gzip normalization keeps dpkg metadata and symlinks consistent" {
    local man="${ROOT}/usr/share/man/man1" hash
    mkdir -p "${man}"
    printf 'manual page\n' >"${BATS_TEST_TMPDIR}/plain"
    gzip -c "${BATS_TEST_TMPDIR}/plain" >"${man}/foo.1.gz"
    ln -s foo.1.gz "${man}/bar.1.gz"
    hash="$(md5sum "${man}/foo.1.gz" | cut -d' ' -f1)"
    printf '%s\n%s\n' "${man}/foo.1.gz" "${man}/bar.1.gz" >"${INFO}/pkg.list"
    printf '%s  %s\n' "${hash}" "${man#/}/foo.1.gz" >"${INFO}/pkg.md5sums"
    run_normalizer "${ROOT}/usr/share/man" gz

    [ -f "${man}/foo.1" ]
    [ ! -e "${man}/foo.1.gz" ]
    [ -L "${man}/bar.1" ]
    [ "$(readlink "${man}/bar.1")" = foo.1 ]
    grep -Fxq "${man}/foo.1" "${INFO}/pkg.list"
    grep -Fxq "${man}/bar.1" "${INFO}/pkg.list"
    hash="$(md5sum "${man}/foo.1" | cut -d' ' -f1)"
    grep -Fq "${hash}  ${man#/}/foo.1" "${INFO}/pkg.md5sums"
}

@test "zstd normalization keeps firmware dpkg metadata idempotent" {
    local fw="${ROOT}/lib/firmware" hash
    mkdir -p "${fw}"
    printf 'firmware payload\n' >"${BATS_TEST_TMPDIR}/firmware"
    zstd -q -c "${BATS_TEST_TMPDIR}/firmware" >"${fw}/device.bin.zst"
    hash="$(md5sum "${fw}/device.bin.zst" | cut -d' ' -f1)"
    printf '%s\n' "${fw}/device.bin.zst" >"${INFO}/pkg.list"
    printf '%s  %s\n' "${hash}" "${fw#/}/device.bin.zst" >"${INFO}/pkg.md5sums"

    run_normalizer "${fw}" zst
    run_normalizer "${fw}" zst

    [ -f "${fw}/device.bin" ]
    [ ! -e "${fw}/device.bin.zst" ]
    grep -Fxq "${fw}/device.bin" "${INFO}/pkg.list"
    hash="$(md5sum "${fw}/device.bin" | cut -d' ' -f1)"
    grep -Fq "${hash}  ${fw#/}/device.bin" "${INFO}/pkg.md5sums"
}
