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
    mkdir -p "${modules}" "${headers}"
    ln -s "${headers}" "${modules}/build"

    run env MODULES_ROOT="${modules}" KERNEL_RELEASE=6.1-test HEADERS="${headers}" \
        bash -c '
            gcc() {
                local output="" previous="" argument
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
        declare -A FILTER_ENV_VARS=([d]=DISTRIBUTION [da]=DISTRIBUTION_ARCH [kc]=KERNEL_CAPABILITIES)
        CHECK_ONLY=false VERBOSITY_LEVEL=0 GREEN= RED= ENDCOLOR=
        warning() { :; }
        information() { :; }
        check_package() { FOUND_EXACT_VERSION=true; return 0; }

        check_case() {
            DISTRIBUTION="$1" DISTRIBUTION_ARCH="$2" KERNEL_CAPABILITIES=()
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
        [ "$(check_case buster i386)" = "${legacy}" ]
        [ "$(check_case bullseye i386)" = "${legacy}" ]
        [ "$(check_case bookworm i386)" = "${legacy}" ]
        [ "$(check_case bookworm i386-pae)" = "${legacy}" ]
        [ "$(check_case trixie i386)" = "${modern}" ]
        [ "$(check_case bookworm amd64)" = "${modern}" ]
    '

    if [ "${status}" -ne 0 ]; then
        printf '%s\n' "${output}" >&2
        false
    fi
}
