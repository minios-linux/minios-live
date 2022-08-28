#!/bin/sh

inst_key_val() {
    local _value
    local _file
    local _default
    _file="$1"; shift
    _key="$1"; shift
    _default="$1"; shift
    _value="$(getarg $@)"
    [ -z "${_value}" ] && _value=$_default
    if [ -n "${_value}" ]; then
        printf '%s="%s"\n' ${_key} ${_value} >> $_file
    fi
    unset _file
    unset _value
}

inst_key_val /etc/vconsole.conf KEYMAP      '' rd.vconsole.keymap       KEYMAP      -d KEYTABLE
inst_key_val /etc/vconsole.conf FONT        '' rd.vconsole.font         FONT        -d SYSFONT
inst_key_val /etc/vconsole.conf FONT_MAP    '' rd.vconsole.font.map     FONT_MAP    -d CONTRANS
inst_key_val /etc/vconsole.conf FONT_UNIMAP '' rd.vconsole.font.unimap  FONT_UNIMAP -d UNIMAP
inst_key_val /etc/vconsole.conf UNICODE      1 rd.vconsole.font.unicode UNICODE vconsole.unicode
inst_key_val /etc/vconsole.conf EXT_KEYMAP  '' rd.vconsole.keymap.ext   EXT_KEYMAP

inst_key_val /etc/locale.conf   LANG        '' rd.locale.LANG           LANG
inst_key_val /etc/locale.conf   LC_ALL      '' rd.locale.LC_ALL         LC_ALL

if [ -f /etc/locale.conf ]; then
    . /etc/locale.conf
    export LANG
    export LC_ALL
fi
