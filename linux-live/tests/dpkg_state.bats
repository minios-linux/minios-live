#!/usr/bin/env bats

setup() {
    ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/../.." && pwd)
    source "$ROOT/linux-live/minioslib"
    WORK_DIR="$BATS_TEST_TMPDIR/work"
    INSTALL_DIR="$WORK_DIR/core"
    mkdir -p "$INSTALL_DIR/var/lib/dpkg"
    printf 'Package: core\nStatus: install ok installed\nArchitecture: amd64\nVersion: 1\n\n' >"$INSTALL_DIR/var/lib/dpkg/status"
    CONTAINER=false
    YELLOW= ENDCOLOR=
    DISTRIBUTION_ARCH=amd64
    COMP_TYPE=zstd ADDITIONAL_COMP_OPTS=
    current_process() { :; }
    copy_build_scripts() { :; }
    information() { :; }
    error() { printf '%s\n' "$*" >&2; }
    chroot() { printf '12.0.0'; }
    minios_module_dpkg_state() { command minios-dpkg-state "$@"; }
}

@test "core export decomposes only the private export root" {
    mount() {
        # Model the merged view without requiring a privileged mount in this test.
        local destination=${!#}
        cp -a "$INSTALL_DIR/." "$destination/"
    }
    umount() { :; }
    mksquashfs() {
        [ ! -e var/lib/dpkg/status ]
        [ -f var/lib/dpkg/status.d/format ]
        command minios-dpkg-state validate "$PWD"
    }
    build_live
    [ -f "$INSTALL_DIR/var/lib/dpkg/status" ]
    [ ! -e "$INSTALL_DIR/var/lib/dpkg/status.d" ]
    [ -z "$(find "$WORK_DIR" -maxdepth 1 -name 'status-export.*' -print)" ]
}

@test "failed core export leaves the mutable source database intact" {
    mount() { cp -a "$INSTALL_DIR/." "${!#}/"; }
    umount() { :; }
    mksquashfs() { return 1; }
    run build_live
    [ "$status" -ne 0 ]
    [ -f "$INSTALL_DIR/var/lib/dpkg/status" ]
    [ ! -e "$INSTALL_DIR/var/lib/dpkg/status.d" ]
}

@test "old live-config cannot be exported as a new-format core" {
    chroot() { printf '11.0.5.26'; }
    run build_live
    [ "$status" -ne 0 ]
    [[ $output == *'require minios-live-config >= 12.0.0'* ]]
    [ -f "$INSTALL_DIR/var/lib/dpkg/status" ]
}

@test "cached legacy package modules are rejected before a partial build" {
    BUILD_SCRIPTS_DIR="$BATS_TEST_TMPDIR/scripts"
    DESKTOP_ENVIRONMENT=xfce
    mkdir -p "$WORK_DIR/image/minios"
    touch "$WORK_DIR/image/minios/00-core-amd64.sb"
    unsquashfs() { printf 'legacy status\n'; }
    run build_modules
    [ "$status" -ne 0 ]
    [[ $output == *'rebuild the complete module chain'* ]]
}

@test "host preflight requires the newest published Debian version for the host architecture" {
    dpkg() {
        if [[ $1 == --print-architecture ]]; then echo i386; else command dpkg "$@"; fi
    }
    curl() {
        [[ ${!#} == */binary-i386/Packages.gz ]] || return 1
        printf 'Package: minios-dpkg-state\nVersion: 12.0.10\nFilename: pool/test/latest_i386.deb\n\nPackage: unrelated\nVersion: 99\n\nPackage: minios-dpkg-state\nVersion: 12.0.9\nFilename: pool/test/old_i386.deb\n' | gzip -c
    }
    dpkg-query() { echo 'installed 12.0.9'; }
    run require_host_dpkg_state
    [ "$status" -ne 0 ]
    [[ $output == *'requires minios-dpkg-state >= 12.0.10 (i386)'* ]]
    [[ $output == *'Download: https://deb.minios.dev/debian/pool/test/latest_i386.deb'* ]]
    [[ $output == *'sudo apt install ./latest_i386.deb'* ]]
}

@test "unavailable index is not treated as an up-to-date host" {
    curl() { return 22; }
    run require_host_dpkg_state
    [ "$status" -ne 0 ]
    [[ $output == *'Cannot check the current minios-dpkg-state version'* ]]
}
