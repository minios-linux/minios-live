#!/bin/sh

[ -n "$DRACUT_SYSTEMD" ] && exit 0

if [ -x $systemdutildir/systemd-vconsole-setup ]; then
    $systemdutildir/systemd-vconsole-setup "$@"
fi

[ -e /etc/vconsole.conf ] && . /etc/vconsole.conf

DEFAULT_FONT=eurlatgr
DEFAULT_KEYMAP=/etc/sysconfig/console/default.kmap

set_keyboard() {
    local param

    [ "${UNICODE}" = 1 ] && param=-u || param=-a
    kbd_mode ${param}
}

set_terminal() {
    local dev=$1

    if [ "${UNICODE}" = 1 ]; then
        printf '\033%%G' >&7
        stty -F ${dev} iutf8
    else
        printf '\033%%@' >&7
        stty -F ${dev} -iutf8
    fi
}

set_keymap() {
    local utf_switch

    if [ -z "${KEYMAP}" ]; then
        [ -f "${DEFAULT_KEYMAP}" ] && KEYMAP=${DEFAULT_KEYMAP}
    fi

    [ -n "${KEYMAP}" ] || return 1

    [ "${UNICODE}" = 1 ] && utf_switch=-u

    loadkeys -q ${utf_switch} ${KEYMAP} ${EXT_KEYMAPS}
}

set_font() {
    local dev=$1; local trans=''; local uni=''

    [ -z "${FONT}" ] && FONT=${DEFAULT_FONT}
    [ -n "${FONT_MAP}" ] && trans="-m ${FONT_MAP}"
    [ -n "${FONT_UNIMAP}" ] && uni="-u ${FONT_UNIMAP}"

    setfont ${FONT} -C ${dev} ${trans} ${uni}
}

dev_close() {
    exec 6>&-
    exec 7>&-
}

dev_open() {
    local dev=$1

    exec 6<${dev} && \
        exec 7>>${dev}
}

dev=/dev/${1#/dev/}
devname=${dev#/dev/}

[ -c "${dev}" ] || {
    echo "Usage: $0 device" >&2
    exit 1
}

dev_open ${dev}

for fd in 6 7; do
    if ! [ -t ${fd} ]; then
        echo "ERROR: File descriptor not opened: ${fd}" >&2
        dev_close
        exit 1
    fi
done

set_keyboard
set_terminal ${dev}
set_font ${dev}
set_keymap

dev_close

