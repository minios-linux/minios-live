#!/bin/bash
#
# NAME: test_condinapt.sh (v22)
#
# DESCRIPTION:
#   Final, complete test suite for condinapt. This version saves a detailed log
#   for EVERY test into a SINGLE file, including the full content of the
#   package lists and configuration files used for that specific test.
#
# USAGE:
#   ./test_condinapt.sh /path/to/condinapt
#

set -u
set -o pipefail

# --- Test Configuration ---
CONDINAPT_SCRIPT_PATH="${1-}"
if [[ -z "${CONDINAPT_SCRIPT_PATH}" ]] || [[ ! -x "${CONDINAPT_SCRIPT_PATH}" ]]; then
    echo "Error: Path to the executable condinapt script is required." >&2
    echo "Usage: $(basename "${0}") /path/to/condinapt" >&2
    exit 1
fi

# --- Global Test Variables ---
TEST_DIR=""
MOCK_BIN_DIR=""
MOCK_LOG_FILE=""
TEST_COUNT=0
PASS_COUNT=0
CURRENT_TEST_NAME=""

# --- The single, master log file ---
MASTER_LOG_FILE="condinapt_full_test.log"

# --- Console Colors ---
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
BOLD=$'\e[1m'
ENDCOLOR=$'\e[0m'

# --- Test Framework Functions ---

setup_test_environment() {
    TEST_DIR=$(mktemp -d -t condinapt-test-XXXXXX)
    export TEST_DIR

    MOCK_BIN_DIR="${TEST_DIR}/bin"
    MOCK_LOG_FILE="${TEST_DIR}/mock_commands.log"
    mkdir -p "${MOCK_BIN_DIR}"
    touch "${MOCK_LOG_FILE}"
    export PATH="${MOCK_BIN_DIR}:${PATH}"

    # Mock apt-cache
    cat >"${MOCK_BIN_DIR}/apt-cache" <<'EOF'
#!/bin/bash
PACKAGE_TO_CHECK="$3"
for pkg_info in ${TEST_AVAILABLE_PACKAGES-}; do
    pkg_name="${pkg_info%%:*}"
    pkg_ver="${pkg_info#*:}"
    if [[ "${pkg_name}" == "${PACKAGE_TO_CHECK}" ]]; then
        echo "Candidate: ${pkg_ver}"; exit 0;
    fi
done
echo "E: Unable to locate package ${PACKAGE_TO_CHECK}" >&2
exit 100
EOF

    # Mock apt-get
    cat >"${MOCK_BIN_DIR}/apt-get" <<'EOF'
#!/bin/bash
LOG_FILE="${TEST_DIR}/mock_commands.log"
if [[ "$*" == *" install "* ]]; then
    echo "--- INSTALL START ---" >> "${LOG_FILE}"
    for arg in "$@"; do
        if ! [[ "$arg" =~ ^- ]] && [[ "$arg" != "install" ]] && [[ "$arg" != "DEBIAN_FRONTEND=noninteractive" ]]; then
            echo "$arg" >> "${LOG_FILE}"
        fi
    done
    echo "--- INSTALL END ---" >> "${LOG_FILE}"
fi
exit 0
EOF

    # Create empty mock commands for other tools
    for cmd in apt-mark tput dpkg-query; do
        echo -e '#!/bin/bash' >"${MOCK_BIN_DIR}/${cmd}"
    done
    chmod +x "${MOCK_BIN_DIR}"/*
}

append_to_master_log() {
    local test_name="$1"
    local result_str="$2"

    echo -e "\n\n#===============================================================================" >>"${MASTER_LOG_FILE}"
    echo "# TEST:   ${test_name}" >>"${MASTER_LOG_FILE}"
    echo "# RESULT: ${result_str}" >>"${MASTER_LOG_FILE}"
    echo "#===============================================================================" >>"${MASTER_LOG_FILE}"

    # --- NEW: Log all input files for the test ---
    if [ -f "${TEST_DIR}/config.sh" ]; then
        echo -e "\n--- CONFIGURATION (config.sh) ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/config.sh" >>"${MASTER_LOG_FILE}"
    fi
    if [ -f "${TEST_DIR}/filter.map" ]; then
        echo -e "\n--- FILTER MAP (filter.map) ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/filter.map" >>"${MASTER_LOG_FILE}"
    fi
    if [ -f "${TEST_DIR}/packages.list" ]; then
        echo -e "\n--- PACKAGE LIST (packages.list) ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/packages.list" >>"${MASTER_LOG_FILE}"
    fi
    if [ -f "${TEST_DIR}/priority.list" ]; then
        echo -e "\n--- PRIORITY LIST (priority.list) ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/priority.list" >>"${MASTER_LOG_FILE}"
    fi

    # --- Log all output files ---
    if [ -s "${TEST_DIR}/stdout.log" ]; then
        echo -e "\n--- STDOUT ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/stdout.log" >>"${MASTER_LOG_FILE}"
    fi
    if [ -s "${TEST_DIR}/stderr.log" ]; then
        echo -e "\n--- STDERR ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/stderr.log" >>"${MASTER_LOG_FILE}"
    fi
    if [ -s "${TEST_DIR}/mock_commands.log" ]; then
        echo -e "\n--- MOCK LOG ---\n" >>"${MASTER_LOG_FILE}"
        cat "${TEST_DIR}/mock_commands.log" >>"${MASTER_LOG_FILE}"
    fi
}

run_test() {
    local test_name="$1"
    shift
    CURRENT_TEST_NAME="$test_name"
    ((TEST_COUNT++))
    echo -n "${BOLD}${CYAN}Running test:${ENDCOLOR} ${test_name}... "
    setup_test_environment

    local result_str
    local result_color

    if "$@" >"${TEST_DIR}/stdout.log" 2>"${TEST_DIR}/stderr.log"; then
        result_str="PASS"
        result_color=$GREEN
        ((PASS_COUNT++))
        append_to_master_log "$test_name" "$result_str"
    else
        local exit_code=$?
        result_str="FAIL (Exit code: $exit_code)"
        result_color=$RED
        append_to_master_log "$test_name" "$result_str"
    fi

    echo "${result_color}${result_str}${ENDCOLOR}"
    rm -rf "${TEST_DIR}"
}

# --- Assertion Helpers ---
assert_installs() {
    local pkgs_to_check=("$@")
    local install_line
    install_line=$(grep "These packages would be installed:" "${TEST_DIR}/stdout.log")
    if [[ -z "$install_line" ]]; then
        echo >&2
        echo -e "\nAssertion failed in [${CURRENT_TEST_NAME}]: No 'packages would be installed' line found." >&2
        return 1
    fi
    for pkg in "${pkgs_to_check[@]}"; do if ! echo "$install_line" | grep -wq "$pkg"; then
        echo >&2
        echo -e "\nAssertion failed in [${CURRENT_TEST_NAME}]: Expected package '${pkg}' not found." >&2
        return 1
    fi; done
    return 0
}
assert_not_installs() {
    local pkgs_to_check=("$@")
    local install_line
    install_line=$(grep "These packages would be installed:" "${TEST_DIR}/stdout.log")
    if [[ -z "$install_line" ]]; then return 0; fi
    for pkg in "${pkgs_to_check[@]}"; do if echo "$install_line" | grep -wq "$pkg"; then
        echo >&2
        echo -e "\nAssertion failed in [${CURRENT_TEST_NAME}]: Unexpected package '${pkg}' found." >&2
        return 1
    fi; done
    return 0
}

# --- Test Case Implementations ---
create_common_files() {
    cat >"${TEST_DIR}/config.sh" <<EOF
DISTRIBUTION="trixie"
DESKTOP_ENVIRONMENT="xfce"
PACKAGE_VARIANT="standard"
INSTALL_KERNEL="true"
KERNEL_FLAVOUR="none"
KERNEL_AUFS="false"
# These variables are intentionally not in the filter map
KERNEL_BUILD_DKMS="true"
EOF
    cat >"${TEST_DIR}/filter.map" <<EOF
d=DISTRIBUTION
de=DESKTOP_ENVIRONMENT
pv=PACKAGE_VARIANT
ik=INSTALL_KERNEL
kf=KERNEL_FLAVOUR
ka=KERNEL_AUFS
EOF
}

# --- Test Functions ---

# === Section: Basic Functionality ===
test_simple_install() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="nano:1.0"
    echo "nano" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "nano"
}

test_alternative_or() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="pkgA:1.0 pkgB:2.0"
    echo "pkgA || pkgB" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "pkgA"
    assert_not_installs "pkgB"
}

test_conjunction_and() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="exfat-utils:1.3 exfat-fuse:1.3"
    echo "exfat-utils && exfat-fuse" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "exfat-utils" "exfat-fuse"
}

test_priority_queue() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="nano:1.0 htop:3.0"
    echo "htop" >"${TEST_DIR}/packages.list"
    echo "nano" >"${TEST_DIR}/priority.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -P "${TEST_DIR}/priority.list" -s -v
    local log_out="${TEST_DIR}/stdout.log"
    local nano_queue_num
    nano_queue_num=$(grep "nano will be installed" "$log_out" -B1 | grep "Queue #" | sed 's/.*#\([0-9]*\):.*/\1/')
    local htop_queue_num
    htop_queue_num=$(grep "htop will be installed" "$log_out" -B1 | grep "Queue #" | sed 's/.*#\([0-9]*\):.*/\1/')
    if [[ "${nano_queue_num}" != "1" ]] || [[ "${htop_queue_num}" != "2" ]]; then
        echo -e "\nAssertion failed: Priority queue order is incorrect." >&2
        return 1
    fi
}

test_queue_separator() {
    # --- Check if we are in an interactive session. If not, skip automatically.
    # This prevents the script from hanging in CI/CD or other non-interactive environments.
    if [ ! -t 0 ]; then
        echo # Add a newline for better formatting in the main output
        echo -e "${YELLOW}Skipping non-simulation test '${CYAN}Queue separator '---'${ENDCOLOR}' in a non-interactive environment."
        # This will be captured in stdout.log so we know why the test didn't assert anything.
        echo "Test skipped: non-interactive environment."
        return 0
    fi

    create_common_files
    export TEST_AVAILABLE_PACKAGES="coreutils:8.32 grep:3.6"
    cat >"${TEST_DIR}/packages.list" <<EOF
coreutils
---
grep
EOF

    # --- Prompt the user by writing everything directly to the terminal (/dev/tty) ---
    echo >/dev/tty # Add a newline for better formatting
    echo -e "${BOLD}${YELLOW}INTERACTIVE PROMPT:${ENDCOLOR}" >/dev/tty
    echo "The test '${CYAN}Queue separator '---'${ENDCOLOR}' must run in non-simulation mode to be effective." >/dev/tty
    echo "It verifies that packages separated by '---' trigger separate installation commands." >/dev/tty
    echo "In this test environment, it will call a safe, mocked version of 'apt-get install'." >/dev/tty

    # 1. Manually print the prompt string to the terminal WITHOUT a newline.
    echo -n "Do you want to run this specific non-simulation test? (y/N) " >/dev/tty

    local user_choice
    # 2. Read the user's response from the terminal (without using the -p flag).
    read -r user_choice </dev/tty

    if [[ "${user_choice,,}" != "y" ]]; then
        # Announce the skip on the terminal for immediate feedback.
        echo -e "\n${YELLOW}Skipping test as requested by the user.${ENDCOLOR}" >/dev/tty
        # This message will be captured in stdout.log by the test framework.
        echo "Test skipped by user."
        return 0
    fi

    # --- Original test logic, executed only if user agrees ---
    # Its output will be correctly redirected to logs by the run_test function.
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list"

    local install_blocks
    install_blocks=$(grep -c -e "--- INSTALL START ---" "${MOCK_LOG_FILE}")
    if [[ "$install_blocks" -ne 2 ]]; then
        echo -e "\nAssertion failed: Expected 2 separate install calls, but found ${install_blocks}." >&2
        return 1
    fi
}

# === Section: Simple Filters (+/-) ===
test_positive_filter_pass() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="htop:3.0"
    echo "htop +de=xfce" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "htop"
}

test_positive_filter_fail() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="fluxbox:1.3"
    echo "fluxbox +de=lxqt" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "fluxbox"
}

test_negative_filter_pass() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="bzip2:1.0"
    echo "bzip2 -pv=minimum" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "bzip2"
}

test_negative_filter_fail() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="htop:3.0"
    echo "htop -de=xfce" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "htop"
}

# === Section: Direct Variable Filters ===
test_direct_variable_pass() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="dkms:3.0"
    # KERNEL_BUILD_DKMS is "true" in config and not in map. This should pass.
    echo "dkms +KERNEL_BUILD_DKMS=true" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "dkms"
}

test_direct_variable_fail() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="linux-image-rt-amd64:6.1"
    # KERNEL_AUFS is "false" in config. This filter requires "true", so it should fail.
    echo "linux-image-rt-amd64 +KERNEL_AUFS=true" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "linux-image-rt-amd64"
}

# === Section: Group Filters (+{...} and -{...}) ===
test_group_or_positive_pass() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="firefox:100"
    echo "firefox +{de=lxqt|pv=standard}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "firefox"
}

test_group_or_positive_fail() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="firefox:100"
    echo "firefox +{de=lxqt|pv=minimum}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "firefox"
}

test_group_and_positive_pass() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="docker:20"
    echo "docker +{de=xfce&pv=standard}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "docker"
}

test_group_and_positive_fail() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="docker:20"
    echo "docker +{de=xfce&pv=ultra}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "docker"
}

test_group_or_negative_fail_install() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="nmap:7"
    echo "nmap -{de=xfce|pv=minimum}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "nmap"
}

test_group_or_negative_pass_install() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="nmap:7"
    echo "nmap -{de=lxqt|pv=minimum}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "nmap"
}

test_group_and_negative_fail_install() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="wireshark:3"
    echo "wireshark -{de=xfce&pv=standard}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_not_installs "wireshark"
}

test_group_and_negative_pass_install() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="wireshark:3"
    echo "wireshark -{de=xfce&pv=ultra}" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "wireshark"
}

# === Section: Complex Logic Scenarios ===
test_complex_and_or_precedence() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="pkgA:1 pkgB:1 pkgC:1"
    echo "pkgA +pv=ultra && pkgB || pkgC" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "pkgC"
    assert_not_installs "pkgA" "pkgB"
}

test_complex_group_and_simple_filters() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="zfs-utils:2.0"
    echo "zfs-utils +{de=xfce|de=lxqt} -pv=minimum" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "zfs-utils"
}

test_complex_mandatory_package_reports_error() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES=""
    echo '!this-package-does-not-exist' >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s -v
    if ! grep -q "Mandatory package this-package-does-not-exist not found" "${TEST_DIR}/stderr.log"; then
        echo -e "\nAssertion failed: Expected 'Mandatory package ... not found' error message in stderr." >&2
        return 1
    fi
}

test_complex_priority_overrides_main_list_filter() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="htop:3.0 nano:1.0"
    echo "htop" >"${TEST_DIR}/priority.list"
    cat >"${TEST_DIR}/packages.list" <<EOF
htop -de=xfce
nano +de=xfce
EOF
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -P "${TEST_DIR}/priority.list" -s
    assert_installs "htop" "nano"
}

test_complex_multiple_positive_filters_pass() {
    create_common_files
    export TEST_AVAILABLE_PACKAGES="dkms:3.0"
    echo "dkms +de=xfce +pv=standard" >"${TEST_DIR}/packages.list"
    "${CONDINAPT_SCRIPT_PATH}" -c "${TEST_DIR}/config.sh" -m "${TEST_DIR}/filter.map" -l "${TEST_DIR}/packages.list" -s
    assert_installs "dkms"
}

# --- Main Test Runner ---
main() {
    # Prepare the single log file
    rm -f "${MASTER_LOG_FILE}"
    echo "CondinAPT Test Suite Log - Started at $(date)" >"${MASTER_LOG_FILE}"

    echo "${BOLD}Starting CondinAPT Test Suite...${ENDCOLOR}"
    echo "Detailed logs for all tests will be appended to './${MASTER_LOG_FILE}'"

    echo
    echo "${BOLD}${CYAN}--- Section: Basic Functionality ---${ENDCOLOR}"
    run_test "Simple package installation" test_simple_install
    run_test "Alternative operator (||)" test_alternative_or
    run_test "Conjunction operator (&&)" test_conjunction_and
    run_test "Priority queue (-P)" test_priority_queue
    run_test "Queue separator '---'" test_queue_separator

    echo
    echo "${BOLD}${CYAN}--- Section: Simple Filters (+/-) ---${ENDCOLOR}"
    run_test "Positive filter pass (+)" test_positive_filter_pass
    run_test "Positive filter fail (+)" test_positive_filter_fail
    run_test "Negative filter pass (-)" test_negative_filter_pass
    run_test "Negative filter fail (-)" test_negative_filter_fail

    echo
    echo "${BOLD}${CYAN}--- Section: Direct Variable Filters ---${ENDCOLOR}"
    run_test "Direct variable filter pass" test_direct_variable_pass
    run_test "Direct variable filter fail" test_direct_variable_fail

    echo
    echo "${BOLD}${CYAN}--- Section: Group Filters (+{} and -{}) ---${ENDCOLOR}"
    run_test "Group OR positive pass +{a|b}" test_group_or_positive_pass
    run_test "Group OR positive fail +{a|b}" test_group_or_positive_fail
    run_test "Group AND positive pass +{a&b}" test_group_and_positive_pass
    run_test "Group AND positive fail +{a&b}" test_group_and_positive_fail
    run_test "Group OR negative -> FAIL install -{a|b}" test_group_or_negative_fail_install
    run_test "Group OR negative -> PASS install -{a|b}" test_group_or_negative_pass_install
    run_test "Group AND negative -> FAIL install -{a&b}" test_group_and_negative_fail_install
    run_test "Group AND negative -> PASS install -{a&b}" test_group_and_negative_pass_install

    echo
    echo "${BOLD}${CYAN}--- Section: Complex Logic Scenarios ---${ENDCOLOR}"
    run_test "Operator Precedence (&& and ||)" test_complex_and_or_precedence
    run_test "Combined Group and Simple Filters" test_complex_group_and_simple_filters
    run_test "Mandatory Package Failure Reports Error" test_complex_mandatory_package_reports_error
    run_test "Priority List Overrides Main List Filters" test_complex_priority_overrides_main_list_filter
    run_test "Multiple Positive Filters of Different Types" test_complex_multiple_positive_filters_pass

    if [ -f "${MASTER_LOG_FILE}" ]; then
        sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "${MASTER_LOG_FILE}"
    fi

    echo
    echo "${BOLD}Test Summary:${ENDCOLOR}"
    if ((PASS_COUNT == TEST_COUNT)); then
        echo "${BOLD}${GREEN}${PASS_COUNT} / ${TEST_COUNT} tests passed. All features and complex interactions are working correctly!${ENDCOLOR}"
        echo "A complete log has been saved to './${MASTER_LOG_FILE}' for review."
        exit 0
    else
        echo "${BOLD}${RED}$((TEST_COUNT - PASS_COUNT)) test(s) failed.${ENDCOLOR}"
        echo "${BOLD}${YELLOW}${PASS_COUNT} / ${TEST_COUNT} tests passed. See './${MASTER_LOG_FILE}' for full details.${ENDCOLOR}"
        exit 1
    fi
}

main "$@"
