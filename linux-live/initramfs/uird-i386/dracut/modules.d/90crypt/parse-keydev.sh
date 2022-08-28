#!/bin/sh

if getargbool 1 rd.luks -n rd_NO_LUKS && \
        [ -n "$(getarg rd.luks.key)" ]; then
    exec 7>/etc/udev/rules.d/65-luks-keydev.rules
    echo 'SUBSYSTEM!="block", GOTO="luks_keydev_end"' >&7
    echo 'ACTION!="add|change", GOTO="luks_keydev_end"' >&7

    for arg in $(getargs rd.luks.key); do
        unset keypath keydev luksdev
        splitsep : "$arg" keypath keydev luksdev

        info "rd.luks.key: keypath='$keypath' keydev='$keydev' luksdev='$luksdev'"

        if [ -z "$keypath" ]; then
            warn 'keypath required!'
            continue
        fi

        # A keydev of '/' is treated as the initrd itself
        if [ "/" = "$keydev" ]; then
            [ -z "$luksdev" ] && luksdev='*'
            echo "$luksdev:$keydev:$keypath" >> /tmp/luks.keys
            continue
        elif [ -n "$keydev" ]; then
            udevmatch "$keydev" >&7 || {
                warn 'keydev incorrect!'
                continue
            }
            printf ', ' >&7
        fi

        {
            printf -- 'RUN+="%s --unique --onetime ' $(command -v initqueue)
            printf -- '--name probe-keydev-%%k '
            printf -- '%s /dev/%%k %s %s"\n' \
                $(command -v probe-keydev) "${keypath}" "${luksdev}"
        } >&7
    done
    unset arg keypath keydev luksdev

    echo 'LABEL="luks_keydev_end"' >&7
    exec 7>&-
fi
