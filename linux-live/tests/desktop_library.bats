#!/usr/bin/env bats

setup() {
    LIVE_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    TARGET_ROOT="${BATS_TEST_TMPDIR}/target root"
    mkdir -p "${TARGET_ROOT}/var/log"
    source "${LIVE_ROOT}/minioslib"
    current_function() { :; }
}

@test "current staged minioslib provides desktop functions without a runtime helper" {
    cp "${LIVE_ROOT}/minioslib" "${TARGET_ROOT}/minioslib"
    [ ! -e "${TARGET_ROOT}/usr/lib/minios-desktop/build-common.sh" ]
    run bash -c '. "$1"; declare -F minios_desktop_install_packages; declare -F minios_desktop_openbox_defaults; declare -F minios_desktop_defaults' _ "${TARGET_ROOT}/minioslib"
    [ "$status" -eq 0 ]
}

@test "cleanup excludes build library from SquashFS while keeping runtime helpers" {
    declare -gA OVERLAY=([upper]="${TARGET_ROOT}")
    MODULE=04-lxqt-desktop
    LIVEKITNAME=minios
    USE_APT_CACHE=true
    REMOVE_DPKG_DB=false
    REMOVE_LARGE_ICONS=false
    KEEP_LOCALES=true
    MULTILINGUAL=false
    LOCALE=en_US
    cp "${LIVE_ROOT}/minioslib" "${TARGET_ROOT}/minioslib"
    mkdir -p "${TARGET_ROOT}/usr/bin"
    cp "${LIVE_ROOT}/scripts/03-gui-base/rootcopy-install/usr/bin/minios-desktop-pipewire-start" \
        "${TARGET_ROOT}/usr/bin/minios-desktop-pipewire-start"
    run chroot_cleanup module
    [ "$status" -eq 0 ]
    [ ! -e "${TARGET_ROOT}/minioslib" ]
    [ -x "${TARGET_ROOT}/usr/bin/minios-desktop-pipewire-start" ]

    if command -v mksquashfs >/dev/null && command -v unsquashfs >/dev/null; then
        mksquashfs "${TARGET_ROOT}" "${BATS_TEST_TMPDIR}/module.sb" \
            -noappend -no-progress -processors 1 -quiet
        run unsquashfs -cat "${BATS_TEST_TMPDIR}/module.sb" minioslib
        [ "$status" -ne 0 ]
        run unsquashfs -cat "${BATS_TEST_TMPDIR}/module.sb" usr/lib/minios-desktop/build-common.sh
        [ "$status" -ne 0 ]
        run unsquashfs -cat "${BATS_TEST_TMPDIR}/module.sb" usr/bin/minios-desktop-pipewire-start
        [ "$status" -eq 0 ]
    fi
}

@test "chroot cleanup clears APT metadata but retains cached packages" {
    declare -gA OVERLAY=([upper]="${TARGET_ROOT}")
    MODULE=04-lxqt-desktop
    LIVEKITNAME=minios
    USE_APT_CACHE=true
    REMOVE_DPKG_DB=false
    REMOVE_LARGE_ICONS=false
    KEEP_LOCALES=true
    MULTILINGUAL=false
    LOCALE=en_US

    mkdir -p "$TARGET_ROOT"/{var/cache/apt/archives,var/lib/apt/lists}
    touch "$TARGET_ROOT"/var/cache/apt/{pkgcache,srcpkgcache}.bin \
        "$TARGET_ROOT/var/cache/apt/archives/keep.deb" \
        "$TARGET_ROOT/var/lib/apt/lists/repo_Packages.lz4" \
        "$TARGET_ROOT/var/lib/apt/lists/repo_Sources.gz" \
        "$TARGET_ROOT/var/lib/apt/lists/repo_Translation-en" \
        "$TARGET_ROOT/var/lib/apt/lists/repo_InRelease" \
        "$TARGET_ROOT/var/lib/apt/lists/repo_Release.gpg" \
        "$TARGET_ROOT/var/lib/apt/lists/deb.example.org_dep11" \
        "$TARGET_ROOT/var/lib/apt/lists/lock"

    run chroot_cleanup module
    [ "$status" -eq 0 ]
    [ ! -e "$TARGET_ROOT/var/cache/apt/pkgcache.bin" ]
    [ ! -e "$TARGET_ROOT/var/cache/apt/srcpkgcache.bin" ]
    [ "$(find "$TARGET_ROOT/var/lib/apt/lists" -maxdepth 1 -type f ! -name lock | wc -l)" -eq 0 ]
    [ -f "$TARGET_ROOT/var/lib/apt/lists/lock" ]
    [ -f "$TARGET_ROOT/var/cache/apt/archives/keep.deb" ]
}
