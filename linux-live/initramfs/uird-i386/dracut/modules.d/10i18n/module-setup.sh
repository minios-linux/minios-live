#!/bin/bash

# called by dracut
check() {
    [[ "$mount_needs" ]] && return 1

    require_binaries setfont loadkeys kbd_mode || return 1

    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    if dracut_module_included "systemd"; then
        unset FONT
        unset KEYMAP
        [[ -f $dracutsysrootdir/etc/vconsole.conf ]] && . $dracutsysrootdir/etc/vconsole.conf
    fi

    KBDSUBDIRS=consolefonts,consoletrans,keymaps,unimaps
    DEFAULT_FONT="${i18n_default_font:-eurlatgr}"
    I18N_CONF="/etc/locale.conf"
    VCONFIG_CONF="/etc/vconsole.conf"

    # This is from 10redhat-i18n.
    findkeymap () {
        local MAPS=$1
        local MAPNAME=${1%.map*}
        local map
        [[ ! -f $dracutsysrootdir$MAPS ]] && \
            MAPS=$(find $dracutsysrootdir${kbddir}/keymaps -type f -name ${MAPNAME} -o -name ${MAPNAME}.map -o -name ${MAPNAME}.map.\*)

        for map in $MAPS; do
            KEYMAPS="$KEYMAPS $map "
            case $map in
                *.gz) cmd=zgrep;;
                *.bz2) cmd=bzgrep;;
                *) cmd=grep ;;
            esac

            for INCL in $($cmd "^include " $map | while read a a b || [ -n "$a" ]; do echo ${a//\"/}; done); do
                for FN in $(find $dracutsysrootdir${kbddir}/keymaps -type f -name $INCL\*); do
                    strstr "$KEYMAPS" " $FN " || findkeymap $FN
                done
            done
        done
    }

# Function gathers variables from distributed files among the tree, maps to
# specified names and prints the result in format "new-name=value".
#
# $@ = list in format specified below (BNF notation)
#
# <list> ::= <element> | <element> " " <list>
# <element> ::= <conf-file-name> ":" <map-list>
# <map-list> ::= <mapping> | <mapping> "," <map-list>
# <mapping> ::= <src-var> "-" <dst-var> | <src-var>
#
# We assume no whitespace are allowed between symbols.
# <conf-file-name> is a file holding <src-var> in your system.
# <src-var> is a variable holding value of meaning the same as <dst-var>.
# <dst-var> is a variable which will be set up inside initramfs.
# If <dst-var> has the same name as <src-var> we can omit <dst-var>.
#
# Example:
# /etc/conf.d/keymaps:KEYMAP,extended_keymaps-EXT_KEYMAPS
# <list> = /etc/conf.d/keymaps:KEYMAP,extended_keymaps-EXT_KEYMAPS
# <element> = /etc/conf.d/keymaps:KEYMAP,extended_keymaps-EXT_KEYMAPS
# <conf-file-name> = /etc/conf.d/keymaps
# <map-list> = KEYMAP,extended_keymaps-EXT_KEYMAPS
# <mapping> = KEYMAP
# <src-var> = KEYMAP
# <mapping> = extended_keymaps-EXT_KEYMAPS
# <src-var> = extended_keymaps
# <dst-var> = EXT_KEYMAPS
    gather_vars() {
        local item map value

        for item in $@
        do
            item=(${item/:/ })
            for map in ${item[1]//,/ }
            do
                map=(${map//-/ })
                if [[ -f "$dracutsysrootdir${item[0]}" ]]; then
                    value=$(grep "^${map[0]}=" "$dracutsysrootdir${item[0]}")
                    value=${value#*=}
                    echo "${map[1]:-${map[0]}}=${value}"
                fi
            done
        done
    }

    install_base() {
        inst_multiple setfont loadkeys kbd_mode stty

        if ! dracut_module_included "systemd"; then
            inst ${moddir}/console_init.sh /lib/udev/console_init
            inst_rules ${moddir}/10-console.rules
            inst_hook cmdline 20 "${moddir}/parse-i18n.sh"
        fi

        if [[ ${kbddir} != "/usr/share" ]]; then
            inst_dir /usr/share
            for _src in $(eval echo {${KBDSUBDIRS}}); do
                [ ! -e "${initdir}/usr/share/${_src}" ] && ln -s "${kbddir}/${_src}" "${initdir}/usr/share/${_src}"
            done
        fi
    }

    install_all_kbd() {
        local rel f

        for __src in $(eval echo $dracutsysrootdir${kbddir}/{${KBDSUBDIRS}}); do
            _src=${__src#$dracutsysrootdir}
            inst_dir "$_src"
            $DRACUT_CP -L -t "${initdir}/${_src}" "$__src"/*
        done

        # remove unnecessary files
        rm -f -- "${initdir}${kbddir}/consoletrans/utflist"
        find "${initdir}${kbddir}/" -name README\* -delete
        find "${initdir}${kbddir}/" -name '*.gz' -print -quit \
            | while read line || [ -n "$line" ]; do
            inst_multiple gzip
            done

        find "${initdir}${kbddir}/" -name '*.bz2' -print -quit \
            | while read line || [ -n "$line" ]; do
            inst_multiple bzip2
            done
    }

    install_local_i18n() {
        local map

        eval $(gather_vars ${i18n_vars})
        [ -f $dracutsysrootdir$I18N_CONF ] && . $dracutsysrootdir$I18N_CONF
        [ -f $dracutsysrootdir$VCONFIG_CONF ] && . $dracutsysrootdir$VCONFIG_CONF

        shopt -q -s nocasematch
        if [[ ${UNICODE} ]]
        then
            if [[ ${UNICODE} = YES || ${UNICODE} = 1 ]]
            then
                UNICODE=1
            elif [[ ${UNICODE} = NO || ${UNICODE} = 0 ]]
            then
                UNICODE=0
            else
                UNICODE=''
            fi
        fi
        if [[ ! ${UNICODE} && ${LANG} =~ .*\.UTF-?8 ]]
        then
            UNICODE=1
        fi
        shopt -q -u nocasematch

        # Gentoo user may have KEYMAP set to something like "-u pl2",
        KEYMAP=${KEYMAP#-* }

        # openSUSE user may have KEYMAP set to something like ".gz"
        KEYMAP=${KEYMAP/.gz/}

        # KEYTABLE is a bit special - it defines base keymap name and UNICODE
        # determines whether non-UNICODE or UNICODE version is used

        if [[ ${KEYTABLE} ]]; then
           if [[ ${UNICODE} == 1 ]]; then
               [[ ${KEYTABLE} =~ .*\.uni.* ]] || KEYTABLE=${KEYTABLE%.map*}.uni
           fi
           KEYMAP=${KEYTABLE}
        fi

        # I'm not sure of the purpose of UNIKEYMAP and GRP_TOGGLE.  They were in
        # original redhat-i18n module.  Anyway it won't hurt.
        EXT_KEYMAPS+=\ ${UNIKEYMAP}\ ${GRP_TOGGLE}

        [[ ${KEYMAP} ]] || {
            dinfo 'No KEYMAP configured.'
            return 1
        }

        findkeymap ${KEYMAP}

        for map in ${EXT_KEYMAPS}
        do
            ddebug "Adding extra map: ${map}"
            findkeymap ${map}
        done

        for keymap in ${KEYMAPS}; do
            inst_opt_decompress ${keymap}
        done

        inst_opt_decompress ${kbddir}/consolefonts/${DEFAULT_FONT}.*

        if [[ ${FONT} ]] && [[ ${FONT} != ${DEFAULT_FONT} ]]
        then
            FONT=${FONT%.psf*}
            inst_opt_decompress ${kbddir}/consolefonts/${FONT}.*
        fi

        if [[ ${FONT_MAP} ]]
        then
            FONT_MAP=${FONT_MAP%.trans}
            # There are three different formats that setfont supports
            inst_simple ${kbddir}/consoletrans/${FONT_MAP} \
            || inst_simple ${kbddir}/consoletrans/${FONT_MAP}.trans \
            || inst_simple ${kbddir}/consoletrans/${FONT_MAP}_to_uni.trans \
            || dwarn "Could not find FONT_MAP ${FONT_MAP}!"
        fi

        if [[ ${FONT_UNIMAP} ]]
        then
            FONT_UNIMAP=${FONT_UNIMAP%.uni}
            inst_simple ${kbddir}/unimaps/${FONT_UNIMAP}.uni
        fi

        if dracut_module_included "systemd" && [[ -f $dracutsysrootdir${I18N_CONF} ]]; then
            inst_simple ${I18N_CONF}
        else
            mksubdirs ${initdir}${I18N_CONF}
            print_vars LC_ALL LANG >> ${initdir}${I18N_CONF}
        fi

        if dracut_module_included "systemd" && [[ -f $dracutsysrootdir${VCONFIG_CONF} ]]; then
            inst_simple ${VCONFIG_CONF}
        else
            mksubdirs ${initdir}${VCONFIG_CONF}
            print_vars KEYMAP EXT_KEYMAPS UNICODE FONT FONT_MAP FONT_UNIMAP >> ${initdir}${VCONFIG_CONF}
        fi

        return 0
    }

    checks() {
        for kbddir in ${kbddir} /usr/lib/kbd /lib/kbd /usr/share /usr/share/kbd
        do
            [[ -d "$dracutsysrootdir${kbddir}" ]] && \
                for dir in ${KBDSUBDIRS//,/ }
            do
                [[ -d "$dracutsysrootdir${kbddir}/${dir}" ]] && continue
                false
            done && break
            kbddir=''
        done

        [[ -f $dracutsysrootdir$I18N_CONF && -f $dracutsysrootdir$VCONFIG_CONF ]] || \
            [[ ! ${hostonly} || ${i18n_vars} ]] || {
            derror 'i18n_vars not set!  Please set up i18n_vars in ' \
                'configuration file.'
        }
        return 0
    }

    if checks; then
        install_base

        if [[ ${hostonly} ]] && ! [[ ${i18n_install_all} == "yes" ]]; then
            install_local_i18n || install_all_kbd
        else
            install_all_kbd
        fi
    fi
}
