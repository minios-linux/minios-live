#!/usr/bin/env bats

setup() {
    LIVE_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    WORK_DIR="${BATS_TEST_TMPDIR}/work"
    BUILD_SCRIPTS_DIR="${LIVE_ROOT}"
    LIVEKITNAME="minios"
    NAMED_BOOT_FILES="false"
    BOOTLOADER="syslinux-native"
    PACKAGE_VARIANT="standard"

    mkdir -p "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/locale"

    source "${LIVE_ROOT}/minioslib"
    current_process() { :; }
    information() { :; }
    warning() { :; }
}

kernel_config_files() {
    printf '%s\n' \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux/lang/"??_??.cfg \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/grub.template.cfg"
}

assert_kernel_lines() {
    local expected="${1}"
    local file line count

    while IFS= read -r file; do
        count=0
        while IFS= read -r line; do
            [[ "${line}" == *"${expected}"* ]]
            count=$((count + 1))
        done < <(grep -E '^(APPEND|    linux )' "${file}")
        [ "${count}" -gt 0 ]
    done < <(kernel_config_files)
}

@test "serial console parameters are omitted when disabled" {
    SERIAL_CONSOLE="false"
    create_config_files

    run grep -R -F 'console=ttyS0,115200n8' "${WORK_DIR}/image/${LIVEKITNAME}/boot"
    [ "${status}" -eq 1 ]
    ! grep -R -Fq 'SERIAL 0 115200 0' "${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux"
    ! grep -R -Fq 'serial --unit=0 --speed=115200' "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub"
}

@test "serial console reaches bootloaders and every generated kernel entry" {
    SERIAL_CONSOLE="true"
    create_config_files

    assert_kernel_lines 'console=tty0 console=ttyS0,115200n8'
    grep -Fxq 'SERIAL 0 115200 0' "${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux/syslinux.multilang.cfg"
    for file in "${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux/lang/"*.cfg; do
        grep -Fxq 'SERIAL 0 115200 0' "${file}"
    done
    for file in \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/languages.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/grub.template.cfg"; do
        grep -Fxq 'if [ "$grub_platform" = "pc" ]; then' "${file}"
        grep -Fxq '    serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1' "${file}"
        grep -Fxq '    terminal_input console serial' "${file}"
        grep -Fxq '    terminal_output gfxterm serial' "${file}"
        grep -Fxq 'fi' "${file}"
        if command -v grub-script-check >/dev/null 2>&1; then
            grub-script-check "${file}"
        fi
    done

    grep -Fq '"serial.mod" "terminfo.mod" "acpi.mod"' "${LIVE_ROOT}/minioslib"
}

@test "Secure Boot falls back to GRUB embedded unicode font" {
    SERIAL_CONSOLE="false"
    create_config_files

    for file in \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/languages.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/grub.template.cfg"; do
        grep -Fxq 'if [ "$lockdown" = "y" ]; then' "${file}"
        grep -Fxq '    loadfont (memdisk)/fonts/unicode.pf2' "${file}"
        grep -Fxq '    insmod font' "${file}"
        ! grep -Fq 'if ! loadfont' "${file}"
        ! grep -Fq 'set lockdown=' "${file}"
        if command -v grub-script-check >/dev/null 2>&1; then
            grub-script-check "${file}"
        fi
    done
}

@test "GRUB 2.12 graphics are initialized before theme loading" {
    SERIAL_CONSOLE="false"
    create_config_files

    for file in \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/languages.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg" \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/grub.template.cfg"; do
        grep -Fxq 'echo -n ""' "${file}"
        first_init=$(grep -n -F 'echo -n ""' "${file}" | head -n1 | cut -d: -f1)
        first_theme=$(grep -n -E '^[[:space:]]*set theme=' "${file}" | head -n1 | cut -d: -f1)
        [ -n "${first_init}" ]
        [ -n "${first_theme}" ]
        [ "${first_init}" -lt "${first_theme}" ]
    done
}

@test "accepted menu keeps Start MiniOS as automatic default" {
    SERIAL_CONSOLE="false"
    create_config_files

    grep -Fxq 'set resume=$"Start MiniOS"' \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg"
    grep -Fq 'menuentry "$resume" --class resume' \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg"
    grep -Fq 'menuentry "Start MiniOS" --class resume' \
        "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/grub.template.cfg"
    grep -Fq 'perchdir=resume' "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/main.cfg"
    grep -Fq 'perchdir=resume' "${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/grub.template.cfg"
    grep -Fq 'local RESUME="Start MiniOS"' "${LIVE_ROOT}/minioslib"
    grep -Fq 'local CHOOSE_SESSION="Choose a saved session"' "${LIVE_ROOT}/minioslib"
    grep -Fq 'local FRESH_START="Start without saving"' "${LIVE_ROOT}/minioslib"
    grep -Fq 'local COPY_RAM="Run from RAM"' "${LIVE_ROOT}/minioslib"
}

@test "GRUB starts with English boot modes and exposes F1 and F2 actions" {
    create_config_files
    local grub="${WORK_DIR}/image/${LIVEKITNAME}/boot/grub"

    cmp "${grub}/grub.cfg" "${grub}/grub.multilang.cfg"
    grep -Fxq 'set lang=en_US' "${grub}/grub.cfg"
    grep -Fxq 'set lang_utf=en_US.UTF-8' "${grub}/grub.cfg"
    grep -Fxq 'source /minios/boot/grub/main.cfg' "${grub}/grub.cfg"
    ! grep -q '^menuentry ' "${grub}/grub.cfg"
    run awk '/^menuentry / { print $(NF-1) }' "${grub}/main.cfg"
    [ "${output}" = $'resume\nnew\nswitch\nlive\nram' ]
    grep -Fxq 'source /minios/boot/grub/navigation.cfg' "${grub}/main.cfg"
    grep -Fxq 'source /minios/boot/grub/navigation.cfg' "${grub}/grub.template.cfg"
    grep -Fq -- '--hotkey=f1 --id minios-help' "${grub}/navigation.cfg"
    grep -Fq -- '--hotkey=f2 --id minios-language' "${grub}/navigation.cfg"

    if command -v grub-script-check >/dev/null 2>&1; then
        for file in "${grub}/"*.cfg; do
            grub-script-check "${file}"
        done
    fi
}

@test "GRUB language selection is untimed and highlights the active locale" {
    create_config_files
    local grub="${WORK_DIR}/image/${LIVEKITNAME}/boot/grub"
    grep -Fxq 'set default="$lang"' "${grub}/languages.cfg"
    grep -Fxq 'set timeout=-1' "${grub}/languages.cfg"
    ! grep -Fq 'set timeout=10' "${grub}/languages.cfg"
    grep -Fxq '    export minios_interactive' "${grub}/navigation.cfg"
    grep -Fxq 'if [ "$minios_interactive" = "1" ]; then' "${grub}/main.cfg"
    for lang in en_US ru_RU de_DE es_ES fr_FR id_ID it_IT pt_BR pt_PT; do
        grep -Fq -- "--id ${lang} {" "${grub}/languages.cfg"
        grep -Fq "lang_utf=\"${lang}.UTF-8\"" "${grub}/languages.cfg"
        [ -s "${grub}/minios-theme/languages_${lang}.txt" ]
    done
}

@test "GRUB navigation changes hint text only, preserving theme and timer styling" {
    create_config_files
    local themes="${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/minios-theme"
    local sources="${LIVE_ROOT}/bootfiles/boot/grub/minios-theme"
    local lang source mode
    for lang in en_US ru_RU de_DE es_ES fr_FR id_ID it_IT pt_BR pt_PT; do
        source="${sources}/theme_${lang}.txt"
        [ -f "${source}" ] || source="${sources}/theme.txt"
        for mode in theme languages; do
            diff -u <(sed '/^[[:space:]]*text = "\[/d' "${source}") \
                <(sed '/^[[:space:]]*text = "\[/d' "${themes}/${mode}_${lang}.txt")
        done
    done
    grep -Fq '[F1]' "${themes}/theme_en_US.txt"
    grep -Fq '[F2]' "${themes}/theme_ru_RU.txt"
    grep -Fq '[Esc]' "${themes}/languages_en_US.txt"
}

@test "GRUB module pruning keeps the help input command" {
    GRUB_REMOVE_UNUSED_MODULES=true
    local modules="${WORK_DIR}/image/${LIVEKITNAME}/boot/grub/i386-pc"
    mkdir -p "${modules}"
    touch "${modules}/read.mod" "${modules}/unused.mod"
    remove_unused_grub_modules
    [ -f "${modules}/read.mod" ]
    [ ! -e "${modules}/unused.mod" ]
}

@test "SYSLINUX starts with exactly five visible English modes and hidden F2 navigation" {
    create_config_files
    local syslinux="${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux"
    cmp "${syslinux}/syslinux.cfg" "${syslinux}/syslinux.multilang.cfg"
    cmp "${syslinux}/syslinux.multilang.cfg" "${syslinux}/lang/en_US.cfg"
    grep -Fxq 'UI minios-menu.c32' "${syslinux}/syslinux.cfg"
    grep -Fxq 'TIMEOUT 100' "${syslinux}/syslinux.cfg"
    grep -Fxq 'DEFAULT default' "${syslinux}/syslinux.cfg"
    ! grep -Fxq 'MENU HIDDEN' "${syslinux}/syslinux.cfg"
    grep -Fxq 'MENU HIDDENKEY F2 minios-language' "${syslinux}/syslinux.cfg"
    grep -Fxq 'F1 help/modes_en_US.txt zblack.png' "${syslinux}/syslinux.cfg"
    run awk '/^MENU LABEL / { sub(/^MENU LABEL /, ""); print }' "${syslinux}/syslinux.cfg"
    [ "${output}" = $'Start MiniOS\nStart a new session\nChoose a saved session\nStart without saving\nRun from RAM' ]
}

@test "SYSLINUX language transitions resolve to untimed menus with complete encoded help" {
    create_config_files
    local syslinux="${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux"
    python3 - "${syslinux}" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
languages = ('en_US', 'ru_RU', 'de_DE', 'es_ES', 'fr_FR', 'id_ID', 'it_IT', 'pt_BR', 'pt_PT')
for lang in languages:
    encoding = 'cp866' if lang == 'ru_RU' else 'latin1'
    main = (root / 'lang' / (lang + '.cfg')).read_bytes().decode(encoding)
    selector = (root / 'lang' / ('select_' + lang + '.cfg')).read_bytes().decode(encoding)
    interactive = (root / 'lang' / (lang + '-interactive.cfg')).read_text()
    assert 'DEFAULT ' + lang + '\n' in selector
    assert 'TIMEOUT 0\n' in selector and 'TIMEOUT 100' not in selector
    assert 'MENU HIDDENKEY Esc minios-back\n' in selector
    assert interactive.index('INCLUDE lang/' + lang + '.cfg') < interactive.index('TIMEOUT 0')
    for target in languages:
        assert 'CONFIG lang/' + target + '-interactive.cfg\n' in selector
    for text in (main, selector, interactive):
        for line in text.splitlines():
            if line.startswith(('CONFIG ', 'INCLUDE ')):
                assert (root / line.split(maxsplit=1)[1]).is_file(), line
    help_text = (root / 'help' / ('modes_' + lang + '.txt')).read_bytes().decode(encoding)
    lines = help_text.splitlines()
    # 800x600 with the existing 8x16 font: 100 columns, 37 rows.
    assert len(lines) <= 36, (lang, len(lines))
    assert all(len(line) <= 99 for line in lines), lang
    assert 'F2' in help_text and 'Tab' in help_text
    assert '[F1]' in main and '[F2]' in main and '[Tab]' in main
    if lang == 'ru_RU':
        assert 'Запустить MiniOS' in main
        assert 'Сохран' in help_text
PY
}

@test "syslinux-grub still generates the GRUB handoff rather than the native menu" {
    BOOTLOADER=syslinux-grub
    create_config_files
    local config="${WORK_DIR}/image/${LIVEKITNAME}/boot/syslinux/syslinux.cfg"
    grep -Fxq 'DEFAULT grub2' "${config}"
    grep -Fxq 'LINUX /minios/boot/grub/i386-pc/lnxboot.img' "${config}"
    ! grep -q '^UI ' "${config}"
}
