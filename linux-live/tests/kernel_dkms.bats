#!/usr/bin/env bats

setup() {
    LIVE_ROOT="${BATS_TEST_DIRNAME}/.."
    BUILD_SCRIPT="${LIVE_ROOT}/scripts/01-kernel/build"
}

@test "kernel package splitter isolates DKMS packages" {
    body="$(awk '/^split_dkms_package_list\(\)/,/^}/' "${BUILD_SCRIPT}")"
    input="${BATS_TEST_TMPDIR}/packages.list"
    prerequisites="${BATS_TEST_TMPDIR}/prerequisites.list"
    dkms_packages="${BATS_TEST_TMPDIR}/dkms.list"
    cat >"${input}" <<'EOF'
# build dependencies
gcc
dkms
libssl-dev +kp=minios +da=i386
# BEGIN DKMS PACKAGES
realtek-one-dkms==1.2
realtek-two-dkms @bookworm-backports
fallback-package || versioned-driver-dkms=3.0
EOF

    run bash -c "${body}; split_dkms_package_list \"${input}\" \"${prerequisites}\" \"${dkms_packages}\""

    [ "${status}" -eq 0 ]
    [ "$(cat "${prerequisites}")" = $'gcc\ndkms\nlibssl-dev +kp=minios +da=i386' ]
    [ "$(cat "${dkms_packages}")" = $'realtek-one-dkms==1.2\nrealtek-two-dkms @bookworm-backports\nfallback-package || versioned-driver-dkms=3.0' ]
}

@test "kernel package splitter rejects a missing DKMS boundary" {
    body="$(awk '/^split_dkms_package_list\(\)/,/^}/' "${BUILD_SCRIPT}")"
    input="${BATS_TEST_TMPDIR}/packages.list"
    printf '%s\n' gcc realtek-one-dkms >"${input}"

    run bash -c "${body}; split_dkms_package_list \"${input}\" \"${input}.pre\" \"${input}.dkms\""

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"DKMS package boundary is missing"* ]]
}

@test "MiniOS i386 headers rebuild target-native host tools before DKMS" {
    body="$(awk '/^prepare_minios_i386_headers\(\)/,/^}/' "${BUILD_SCRIPT}")"
    modules="${BATS_TEST_TMPDIR}/modules"
    headers="${BATS_TEST_TMPDIR}/headers"
    gcc_log="${BATS_TEST_TMPDIR}/gcc.log"
    mkdir -p "${modules}" "${headers}/scripts/mod"
    : >"${headers}/scripts/mod/symsearch.c"
    ln -s "${headers}" "${modules}/build"

    run env MODULES_ROOT="${modules}" KERNEL_RELEASE=6.12-test GCC_LOG="${gcc_log}" \
        bash -c '
            gcc() {
                local output="" previous="" argument
                printf "%s\n" "$*" >>"${GCC_LOG}"
                for argument in "$@"; do
                    if [ "$previous" = -o ]; then
                        output="$argument"
                        break
                    fi
                    previous="$argument"
                done
                [ -n "$output" ] || return 1
                mkdir -p "${output%/*}"
                : >"$output"
            }
            objdump() { printf "file format elf32-i386\n"; }
            '"${body}"'
            prepare_minios_i386_headers
        '

    if [ "${status}" -ne 0 ]; then
        printf '%s\n' "${output}" >&2
        false
    fi
    grep -Fq -- '-I scripts/include -I tools/include -c -o scripts/mod/symsearch.o scripts/mod/symsearch.c' "${gcc_log}"
    grep -Fq -- '-o scripts/mod/modpost scripts/mod/modpost.o scripts/mod/file2alias.o scripts/mod/sumversion.o scripts/mod/symsearch.o' "${gcc_log}"
    compile_line="$(grep -nF 'scripts/mod/symsearch.c' "${gcc_log}" | cut -d: -f1)"
    link_line="$(grep -nF -- '-o scripts/mod/modpost ' "${gcc_log}" | cut -d: -f1)"
    [ "${compile_line}" -lt "${link_line}" ]
}

@test "MiniOS i386 installs prerequisites before DKMS packages" {
    branch_line="$(grep -nF 'if [ "${KERNEL_PROVIDER}" = minios ] && [ "${DISTRIBUTION_ARCH}" = i386 ]; then' "${BUILD_SCRIPT}" | cut -d: -f1)"
    prerequisites_line="$(grep -nF '/condinapt -l "${TMP_COMBINED}"' "${BUILD_SCRIPT}" | awk -F: 'NR == 1 { print $1 }')"
    prepare_line="$(grep -nF '    prepare_minios_i386_headers' "${BUILD_SCRIPT}" | cut -d: -f1)"
    dkms_line="$(grep -nF '/condinapt -l "${TMP_DKMS_PACKAGES}"' "${BUILD_SCRIPT}" | cut -d: -f1)"

    [ "${branch_line}" -lt "${prerequisites_line}" ]
    [ "${prerequisites_line}" -lt "${prepare_line}" ]
    [ "${prepare_line}" -lt "${dkms_line}" ]
    grep -Fq 'libssl-dev +kp=minios +da=i386' "${LIVE_ROOT}/scripts/01-kernel/packages.list"
}

@test "Realtek package rules select one compatible package per architecture" {
    condinapt="${LIVE_ROOT}/condinapt"
    conditions="${BATS_TEST_TMPDIR}/conditions"
    functions="${BATS_TEST_TMPDIR}/functions"
    awk '/^process_condition\(\)/,/^}/' "${condinapt}" >"${functions}"
    awk '/^check_filter\(\)/,/^}/' "${condinapt}" >>"${functions}"
    grep -E '^realtek-rtl(88xx|8814)au-dkms' "${LIVE_ROOT}/scripts/01-kernel/packages.list" >"${conditions}"

    run env FUNCTIONS="${functions}" CONDITIONS="${conditions}" bash -c '
        set -euo pipefail
        . "${FUNCTIONS}"
        declare -A FILTER_ENV_VARS=([d]=DISTRIBUTION [da]=DISTRIBUTION_ARCH [kc]=KERNEL_CAPABILITIES [kp]=KERNEL_PROVIDER)
        CHECK_ONLY=false VERBOSITY_LEVEL=0 GREEN= RED= ENDCOLOR=
        warning() { :; }
        information() { :; }
        check_package() { FOUND_EXACT_VERSION=true; return 0; }

        check_case() {
            DISTRIBUTION="$1" DISTRIBUTION_ARCH="$2" KERNEL_PROVIDER="$3" KERNEL_CAPABILITIES=()
            PACKAGES_TO_INSTALL=() PACKAGES_TO_HOLD=() MISSING_PACKAGES=()
            while IFS= read -r condition; do
                process_condition "${condition}" false 0 || true
            done <"${CONDITIONS}"
            if [ "${#PACKAGES_TO_INSTALL[@]}" -ne 2 ]; then
                return 1
            fi
            printf "%s\n" "${PACKAGES_TO_INSTALL[@]}"
        }

        legacy=$'"'"'realtek-rtl88xxau-dkms=5.6.4.2~git20240726.63cf0b4-0kali1\nrealtek-rtl8814au-dkms=5.8.5.1~git20240527.d8208c8-0kali1'"'"'
        modern=$'"'"'realtek-rtl88xxau-dkms\nrealtek-rtl8814au-dkms'"'"'
        for arch in amd64 i386 i386-pae; do
            for suite in buster beowulf bullseye chimaera bookworm daedalus bionic focal jammy; do
                [ "$(check_case "${suite}" "${arch}" distribution)" = "${legacy}" ]
                [ "$(check_case "${suite}" "${arch}" minios)" = "${modern}" ]
            done
            for suite in trixie excalibur sid noble; do
                [ "$(check_case "${suite}" "${arch}" distribution)" = "${modern}" ]
                [ "$(check_case "${suite}" "${arch}" minios)" = "${modern}" ]
            done
        done
    '

    if [ "${status}" -ne 0 ]; then
        printf '%s\n' "${output}" >&2
        false
    fi
}

@test "NTFS3 and RTL8188EUS package rules respect kernel source compatibility" {
    functions="${BATS_TEST_TMPDIR}/functions"
    conditions="${BATS_TEST_TMPDIR}/conditions"
    awk '/^process_condition\(\)/,/^}/' "${LIVE_ROOT}/condinapt" >"${functions}"
    awk '/^check_filter\(\)/,/^}/' "${LIVE_ROOT}/condinapt" >>"${functions}"
    grep -E '^(ntfs3-dkms|realtek-rtl8188eus-dkms)' "${LIVE_ROOT}/scripts/01-kernel/packages.list" >"${conditions}"

    run env FUNCTIONS="${functions}" CONDITIONS="${conditions}" bash -c '
        set -euo pipefail
        . "${FUNCTIONS}"
        declare -A FILTER_ENV_VARS=([ks]=KERNEL_SERIES [kc]=KERNEL_CAPABILITIES)
        CHECK_ONLY=false VERBOSITY_LEVEL=0 GREEN= RED= ENDCOLOR=
        warning() { :; }
        information() { :; }
        check_package() { FOUND_EXACT_VERSION=true; return 0; }
        select_packages() {
            KERNEL_SERIES="$1"
            KERNEL_CAPABILITIES=("${@:2}")
            PACKAGES_TO_INSTALL=() PACKAGES_TO_HOLD=() MISSING_PACKAGES=()
            while IFS= read -r condition; do
                process_condition "${condition}" false 0 || true
            done <"${CONDITIONS}"
            printf "%s\n" "${PACKAGES_TO_INSTALL[@]}"
        }
        legacy=realtek-rtl8188eus-dkms=5.3.9~git20230921.3fae723-0kali2
        for series in 4.9 4.15 4.19 5.4 5.10 5.15; do
            [ "$(select_packages "${series}")" = "${legacy}" ]
        done
        for series in 6.1 6.4 6.5 6.6 6.7 6.8 6.9 6.10 6.11 6.12 6.13; do
            [ "$(select_packages "${series}")" = $'"'"'ntfs3-dkms\nrealtek-rtl8188eus-dkms'"'"' ]
            [ "$(select_packages "${series}" ntfs3)" = realtek-rtl8188eus-dkms ]
        done
        [ "$(select_packages 6.14)" = realtek-rtl8188eus-dkms ]
    '
    if [ "${status}" -ne 0 ]; then
        printf '%s\n' "${output}" >&2
        false
    fi
}

@test "RTL8821CU selection follows its packaged BUILD_EXCLUSIVE_KERNEL" {
    functions="${BATS_TEST_TMPDIR}/functions"
    awk '/^process_condition\(\)/,/^}/' "${LIVE_ROOT}/condinapt" >"${functions}"
    awk '/^check_filter\(\)/,/^}/' "${LIVE_ROOT}/condinapt" >>"${functions}"
    condition="$(grep '^realtek-rtl8821cu-dkms ' "${LIVE_ROOT}/scripts/01-kernel/packages.list")"
    run env FUNCTIONS="$functions" CONDITION="$condition" bash -c '
        . "$FUNCTIONS"
        declare -A FILTER_ENV_VARS=([ks]=KERNEL_SERIES [kc]=KERNEL_CAPABILITIES)
        CHECK_ONLY=false VERBOSITY_LEVEL=0 GREEN= RED= ENDCOLOR=
        check_package() { return 0; }
        KERNEL_CAPABILITIES=()
        for KERNEL_SERIES in 4.9 4.15 6.2 6.12; do
            PACKAGES_TO_INSTALL=()
            process_condition "$CONDITION" false 0
            [ "${#PACKAGES_TO_INSTALL[@]}" = 0 ] || exit 1
        done
        for KERNEL_SERIES in 4.19 5.4 5.10 5.15 6.0 6.1; do
            PACKAGES_TO_INSTALL=()
            process_condition "$CONDITION" false 0
            [ "${PACKAGES_TO_INSTALL[*]}" = realtek-rtl8821cu-dkms ] || exit 1
        done
        KERNEL_CAPABILITIES=(rtw88_8821cu) PACKAGES_TO_INSTALL=()
        process_condition "$CONDITION" false 0
        [ "${#PACKAGES_TO_INSTALL[@]}" = 0 ]
    '
    [ "$status" -eq 0 ]
}
