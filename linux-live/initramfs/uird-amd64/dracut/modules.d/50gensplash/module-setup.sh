#!/bin/bash

# called by dracut
check() {
    # TODO: splash_geninitramfs
    # TODO: /usr/share/splashutils/initrd.splash
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    local _opts
    local _splash_theme
    local _splash_res

    call_splash_geninitramfs() {
        local _out _ret

        _out=$(splash_geninitramfs -c "$1" ${@:2} 2>&1)
        _ret=$?

        if [[ ${_out} ]]; then
            local IFS='
'
            for line in ${_out}; do
                if [[ ${line} =~ ^Warning ]]; then
                    dwarn "${line}"
                else
                    derror "${line}"
                    (( $_ret == 0 )) && _ret=1
                fi
            done
        fi

        return ${_ret}
    }

    type -P splash_geninitramfs >/dev/null || return 1

    _opts=''
    if [[ ${DRACUT_GENSPLASH_THEME} ]]; then
        # Variables from the environment
        # They're supposed to be set up by e.g. Genkernel in basis of cmdline args.
        # If user set them he/she would expect to be included only given theme
        # rather then all even if we're building generic initramfs.
        _splash_theme=${DRACUT_GENSPLASH_THEME}
        _splash_res=${DRACUT_GENSPLASH_RES}
    elif [[ ${hostonly} ]]; then
        # Settings from config only in hostonly
        [[ -e $dracutsysrootdir/etc/conf.d/splash ]] && source $dracutsysrootdir/etc/conf.d/splash
        [[ ! ${_splash_theme} ]] && _splash_theme=default
        [[ ${_splash_res} ]] && _opts+=" -r ${_splash_res}"
    else
        # generic
        _splash_theme=--all
    fi

    dinfo "Installing Gentoo Splash (using the ${_splash_theme} theme)"

    pushd "${initdir}" >/dev/null
    mv dev dev.old
    call_splash_geninitramfs "${initdir}" ${_opts} ${_splash_theme} || {
        derror "Could not build splash"
        return 1
    }
    rm -rf dev
    mv dev.old dev
    popd >/dev/null

    inst_multiple chvt
    inst /usr/share/splashutils/initrd.splash /lib/gensplash-lib.sh
    inst_hook pre-pivot 90 "${moddir}"/gensplash-newroot.sh
    inst_hook pre-trigger 10 "${moddir}"/gensplash-pretrigger.sh
    inst_hook emergency 50 "${moddir}"/gensplash-emergency.sh
}
