#!/usr/bin/env bats

setup() {
    LIVE_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    TEST_CONFIG="${BATS_TEST_TMPDIR}/minios_build.conf"
    printf '%s\n' 'OUTPUT_MODE=console' 'LIVE_TIMEZONE=Etc/UTC' 'LOCALE=en_US' >"${TEST_CONFIG}"
}

# Only run startup through console_colors; never execute module installation.
module_initialization() {
    python3 - "$1" <<'PY'
from pathlib import Path
import re
import sys

for line in Path(sys.argv[1]).read_text().splitlines():
    if re.match(r'\s*\.\s+.*minioslib', line):
        line = '. "${TEST_MINIOSLIB}"'
    elif re.match(r'\s*\.\s+.*minios_build\.conf', line):
        line = '. "${TEST_CONFIG}"'
    print(line)
    if line.strip() == "console_colors":
        sys.exit(0)
sys.exit("Missing console_colors startup call")
PY
}

@test "module entry points initialize colors for nounset diagnostics" {
    local script initialization checked=0
    for script in "${LIVE_ROOT}"/scripts/*/*; do
        [ -f "${script}" ] || continue
        grep -Eq '^\s*\.\s+.*minioslib' "${script}" || continue
        if ! initialization="$(module_initialization "${script}")"; then
            printf 'Missing color initialization: %s\n' "${script}" >&2
            return 1
        fi
        run env -i PATH="${PATH}" TEST_MINIOSLIB="${LIVE_ROOT}/minioslib" TEST_CONFIG="${TEST_CONFIG}" \
            bash -eu -c "${initialization}"$'\n''
                OUTPUT_MODE=console
                error "original error is visible"
                warning "original warning is visible"
                information "original information is visible"
                question "original question is visible" <<< "n"
                [ "${RESPONSE}" = n ]
            '
        if [ "${status}" -ne 0 ]; then
            printf 'Startup failed for %s:\n%s\n' "${script}" "${output}" >&2
            return 1
        fi
        [[ "${output}" == *"original error is visible"* ]]
        [[ "${output}" == *"original warning is visible"* ]]
        [[ "${output}" == *"original information is visible"* ]]
        [[ "${output}" == *"original question is visible"* ]]
        checked=$((checked + 1))
    done
    [ "${checked}" -gt 0 ]
}

@test "generated chroot shell initializes colors before diagnostics" {
    local capture="${BATS_TEST_TMPDIR}/chroot-script"
    run env -i PATH="${PATH}" TEST_MINIOSLIB="${LIVE_ROOT}/minioslib" CAPTURE="${capture}" bash -eu -c '
        . "${TEST_MINIOSLIB}"
        console_colors
        current_function() { :; }
        add_chroot_configuration_files() { :; }
        chroot() { cat >"${CAPTURE}"; }
        VARIABLES=OUTPUT_MODE
        chroot_run /unused '\''error "original chroot error is visible"'\''
    '
    [ "${status}" -eq 0 ]

    # Replace chroot-only paths with fixtures; execute the generated shell itself.
    local script
    script="$(python3 - "${capture}" "${LIVE_ROOT}/minioslib" "${TEST_CONFIG}" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).read_text().replace("/minioslib", sys.argv[2])
      .replace("/minios_build.conf", sys.argv[3]))
PY
    )"
    run env -i PATH="${PATH}" bash -eu -c "${script}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"original chroot error is visible"* ]]
}
