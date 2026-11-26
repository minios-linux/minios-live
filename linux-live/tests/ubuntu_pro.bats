#!/usr/bin/env bats

setup() {
    LIVE_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    source "${LIVE_ROOT}/minioslib"
    DISTRIBUTION=bionic
    DISTRIBUTION_PROFILE=ubuntu
    VERBOSITY_LEVEL=1
    UBUNTU_PRO_TOKEN=test-token
    ROOT="${BATS_TEST_TMPDIR}/root"
    mkdir -p "$ROOT"
    current_function() { :; }
    information() { printf '%s\n' "$*"; }
    error() { printf '%s\n' "$*" >&2; }
    run_with_spinner() { shift; "$@"; }
    FAIL_STEP=
    chroot() {
        shift
        if [ "$1" = env ]; then
            shift 2
        fi
        case "$1 $2" in
            "dpkg -l" | "apt-get install" | "apt-get update") return 0 ;;
            "pro attach") [ "$FAIL_STEP" != attach ] ;;
            "pro enable") [ "$FAIL_STEP" != "$3" ] ;;
            "pro detach") printf 'DETACHED\n'; [ "$FAIL_STEP" != detach ] ;;
            "pro status")
                if [ "$FAIL_STEP" = status ]; then
                    printf '{"services":[{"name":"esm-infra","status":"disabled"},{"name":"esm-apps","status":"enabled"}]}\n'
                else
                    printf '{"services":[{"name":"esm-infra","status":"enabled"},{"name":"esm-apps","status":"enabled"}]}\n'
                fi ;;
            "apt-cache policy")
                [ "$FAIL_STEP" != policy ] || return 1
                printf '510 https://esm.ubuntu.com/infra/ubuntu %s-infra-security/main amd64 Packages\n' "$DISTRIBUTION"
                [ "$FAIL_STEP" = indexes ] || printf '510 https://esm.ubuntu.com/apps/ubuntu %s-apps-security/main amd64 Packages\n' "$DISTRIBUTION"
                ;;
            *) return 1 ;;
        esac
    }
}

@test "Ubuntu Pro cleanup preserves installed public keyrings and static client configuration" {
    mkdir -p "$ROOT"/{etc/ubuntu-advantage,etc/apt/preferences.d,etc/apt/sources.list.d,etc/apt/auth.conf.d,etc/apt/trusted.gpg.d,usr/share/keyrings,var/lib/ubuntu-advantage/private,var/lib/apt/lists,var/log}
    touch "$ROOT"/usr/share/keyrings/ubuntu-pro-esm-{infra,apps}.gpg \
        "$ROOT"/etc/ubuntu-advantage/uaclient.conf \
        "$ROOT"/etc/apt/preferences.d/ubuntu-pro-esm-{infra,apps} \
        "$ROOT"/etc/apt/sources.list.d/ubuntu-extra.list \
        "$ROOT"/etc/apt/auth.conf.d/other-repository \
        "$ROOT"/etc/apt/sources.list.d/ubuntu-esm-infra.list \
        "$ROOT"/etc/apt/sources.list.d/ubuntu-esm-apps.sources \
        "$ROOT"/etc/apt/auth.conf.d/90ubuntu-advantage \
        "$ROOT"/etc/apt/trusted.gpg.d/ubuntu-pro-esm-infra.gpg \
        "$ROOT"/var/lib/ubuntu-advantage/private/machine-token.json \
        "$ROOT"/var/lib/apt/lists/esm.ubuntu.com_infra_ubuntu_dists_bionic-infra-security_InRelease \
        "$ROOT"/var/log/ubuntu-advantage.log
    chroot() { return 99; }
    ubuntu_pro_cleanup_traces "$ROOT"
    [ -f "$ROOT/usr/share/keyrings/ubuntu-pro-esm-infra.gpg" ]
    [ -f "$ROOT/usr/share/keyrings/ubuntu-pro-esm-apps.gpg" ]
    [ -f "$ROOT/etc/ubuntu-advantage/uaclient.conf" ]
    [ -f "$ROOT/etc/apt/preferences.d/ubuntu-pro-esm-infra" ]
    [ -f "$ROOT/etc/apt/sources.list.d/ubuntu-extra.list" ]
    [ -f "$ROOT/etc/apt/auth.conf.d/other-repository" ]
    [ ! -e "$ROOT/var/lib/ubuntu-advantage" ]
    [ ! -e "$ROOT/etc/apt/auth.conf.d/90ubuntu-advantage" ]
    [ ! -e "$ROOT/etc/apt/sources.list.d/ubuntu-esm-infra.list" ]
    [ ! -e "$ROOT/etc/apt/sources.list.d/ubuntu-esm-apps.sources" ]
    [ ! -e "$ROOT/etc/apt/trusted.gpg.d/ubuntu-pro-esm-infra.gpg" ]
    [ ! -e "$ROOT/var/lib/apt/lists/esm.ubuntu.com_infra_ubuntu_dists_bionic-infra-security_InRelease" ]
    [ ! -e "$ROOT/var/log/ubuntu-advantage.log" ]
}

@test "successful attachment requires both ESM indexes on every supported Ubuntu LTS" {
    for DISTRIBUTION in bionic focal jammy noble; do
        run ubuntu_pro_attach "$ROOT"
        [ "$status" -eq 0 ]
        [[ "$output" == *'Ubuntu Pro repositories are now active'* ]]
    done
}

@test "attachment errors do not report active ESM repositories" {
    FAIL_STEP=attach
    run ubuntu_pro_attach "$ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" != *'Ubuntu Pro repositories are now active'* ]]
}

@test "a failed ESM enable or missing service or index detaches and fails" {
    for DISTRIBUTION in bionic focal jammy noble; do
        for FAIL_STEP in esm-infra esm-apps status indexes policy; do
            run ubuntu_pro_attach "$ROOT"
            [ "$status" -ne 0 ]
            [[ "$output" == *DETACHED* ]]
            [[ "$output" != *'Ubuntu Pro repositories are now active'* ]]
        done
    done
}

@test "successful detach removes APT caches and indexes recreated by Pro" {
    mkdir -p "$ROOT"/{var/cache/apt/archives,var/lib/apt/lists}
    touch "$ROOT/var/cache/apt/archives/keep.deb"
    chroot() {
        [ "$1 $2 $3" = "$ROOT pro detach" ] || return 1
        touch "$ROOT"/var/cache/apt/{pkgcache,srcpkgcache}.bin \
            "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_InRelease" \
            "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_main_binary-amd64_Packages" \
            "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_main_source_Sources.gz" \
            "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_Release.gpg"
    }
    ubuntu_pro_detach "$ROOT"
    [ ! -e "$ROOT/var/cache/apt/pkgcache.bin" ]
    [ ! -e "$ROOT/var/cache/apt/srcpkgcache.bin" ]
    [ ! -e "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_InRelease" ]
    [ ! -e "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_main_binary-amd64_Packages" ]
    [ ! -e "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_main_source_Sources.gz" ]
    [ ! -e "$ROOT/var/lib/apt/lists/ubuntu_dists_bionic_Release.gpg" ]
    [ -f "$ROOT/var/cache/apt/archives/keep.deb" ]
}

@test "failed detach does not report cleaned subscription" {
    FAIL_STEP=detach
    run ubuntu_pro_detach "$ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" != *'traces successfully removed'* ]]
}

@test "isolated kernel APT imports matching active ESM pockets with separate public keys" {
    acquire="${LIVE_ROOT}/scripts/01-kernel/acquire"
    APT_ROOT="${BATS_TEST_TMPDIR}/apt"
    REPOSITORY_TABLE="$APT_ROOT/repositories.tsv"
    mkdir -p "$APT_ROOT" "$ROOT/keyrings"
    touch "$ROOT"/keyrings/{ubuntu-archive-keyring,ubuntu-pro-esm-infra,ubuntu-pro-esm-apps}.gpg
    eval "$(awk '/^add_repository\(\)/,/^}/' "$acquire")"
    eval "$(awk '/^configure_repositories\(\)/,/^}/' "$acquire" | sed "s|/usr/share/keyrings|$ROOT/keyrings|g")"
    fail() { printf '%s\n' "$*" >&2; exit 1; }
    apt-cache() {
        printf '510 https://esm.ubuntu.com/infra/ubuntu %s-infra-security/main amd64 Packages\n' "$DISTRIBUTION"
        printf '510 https://esm.ubuntu.com/infra/ubuntu %s-infra-updates/main amd64 Packages\n' "$DISTRIBUTION"
        if [ "$FAIL_STEP" != indexes ]; then
            printf '510 https://esm.ubuntu.com/apps/ubuntu %s-apps-security/main amd64 Packages\n' "$DISTRIBUTION"
        fi
    }
    UBUNTU_PRO_REQUIRED=true
    unset UBUNTU_PRO_TOKEN
    KERNEL_SOURCE_FAMILY=ubuntu
    KERNEL_APT_ARCH=amd64
    KERNEL_SNAPSHOT_DATE=
    for DISTRIBUTION in bionic focal jammy noble; do
        KERNEL_SOURCE_SUITE="$DISTRIBUTION"
        configure_repositories
        grep -F "signed-by=$ROOT/keyrings/ubuntu-pro-esm-infra.gpg] https://esm.ubuntu.com/infra/ubuntu ${DISTRIBUTION}-infra-security main" "$APT_ROOT/sources.list"
        grep -F "signed-by=$ROOT/keyrings/ubuntu-pro-esm-apps.gpg] https://esm.ubuntu.com/apps/ubuntu ${DISTRIBUTION}-apps-security main" "$APT_ROOT/sources.list"
        [ "$(grep -c 'esm.ubuntu.com' "$APT_ROOT/sources.list")" -eq 3 ]
        FAIL_STEP=indexes
        run configure_repositories
        [ "$status" -ne 0 ]
        [[ "$output" == *"No active ESM apps repository for the ${DISTRIBUTION} kernel"* ]]
        FAIL_STEP=
    done
    DISTRIBUTION=bionic
    KERNEL_SOURCE_SUITE=focal
    configure_repositories
    ! grep -q 'esm.ubuntu.com' "$APT_ROOT/sources.list"
    KERNEL_SOURCE_SUITE=bionic
    UBUNTU_PRO_REQUIRED=false
    configure_repositories
    ! grep -q 'esm.ubuntu.com' "$APT_ROOT/sources.list"
}

@test "generated kernel configuration records Pro policy but does not contain its token" {
    USE_UBUNTU_PRO=true
    UBUNTU_PRO_TOKEN=test-secret-not-for-chroot
    toggle_shell_options() { :; }
    generate_chroot_configuration_file "$ROOT/minios_build.conf"
    grep -qx 'UBUNTU_PRO_REQUIRED="true"' "$ROOT/minios_build.conf"
    ! grep -q 'test-secret-not-for-chroot\|UBUNTU_PRO_TOKEN' "$ROOT/minios_build.conf"
    USE_UBUNTU_PRO=false
    generate_chroot_configuration_file "$ROOT/minios_build.conf"
    grep -qx 'UBUNTU_PRO_REQUIRED="false"' "$ROOT/minios_build.conf"
    DISTRIBUTION=trixie
    DISTRIBUTION_PROFILE=debian
    USE_UBUNTU_PRO=true
    generate_chroot_configuration_file "$ROOT/minios_build.conf"
    grep -qx 'UBUNTU_PRO_REQUIRED="false"' "$ROOT/minios_build.conf"
}
