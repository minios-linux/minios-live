#!/bin/sh

type crypttab_contains >/dev/null 2>&1 || . /lib/dracut-crypt-lib.sh


_cryptgetargsname() {
    debug_off
    local _o _found _key
    unset _o
    unset _found
    CMDLINE=$(getcmdline)
    _key="$1"
    set --
    for _o in $CMDLINE; do
        if [ "$_o" = "$_key" ]; then
            _found=1;
        elif [ "${_o%=*}" = "${_key%=}" ]; then
            [ -n "${_o%=*}" ] && set -- "$@" "${_o#*=}";
            _found=1;
        fi
    done
    if [ -n "$_found" ]; then
        [ $# -gt 0 ] && printf '%s' "$*"
        return 0
    fi
    return 1;
}

if ! getargbool 1 rd.luks -d -n rd_NO_LUKS; then
    info "rd.luks=0: removing cryptoluks activation"
    rm -f -- /etc/udev/rules.d/70-luks.rules
else
    {
        echo 'SUBSYSTEM!="block", GOTO="luks_end"'
        echo 'ACTION!="add|change", GOTO="luks_end"'
    } > /etc/udev/rules.d/70-luks.rules.new

    PARTUUID=$(getargs rd.luks.partuuid -d rd_LUKS_PARTUUID)
    SERIAL=$(getargs rd.luks.serial -d rd_LUKS_SERIAL)
    LUKS=$(getargs rd.luks.uuid -d rd_LUKS_UUID)
    tout=$(getarg rd.luks.key.tout)

    if [ -e /etc/crypttab ]; then
        while read -r _ _dev _ || [ -n "$_dev" ]; do
            set_systemd_timeout_for_dev "$_dev"
        done < /etc/crypttab
    fi

    if [ -n "$PARTUUID" ]; then
        for uuid in $PARTUUID; do

            uuid=${uuid##luks-}
            if luksname=$(_cryptgetargsname "rd.luks.name=$uuid="); then
                luksname="${luksname#$uuid=}"
            else
                luksname="luks-$uuid"
            fi

            if [ -z "$DRACUT_SYSTEMD" ]; then
                {
                    printf -- 'ENV{ID_PART_ENTRY_UUID}=="*%s*", ' "$uuid"
                    printf -- 'RUN+="%s --settled --unique --onetime ' "$(command -v initqueue)"
                    printf -- '--name cryptroot-ask-%%k %s ' "$(command -v cryptroot-ask)"
                    printf -- '$env{DEVNAME} %s %s"\n' "$luksname" "$tout"
                } >> /etc/udev/rules.d/70-luks.rules.new
            else
                luksname=$(dev_unit_name "$luksname")
                luksname="$(str_replace "$luksname" '\' '\\')"

                if ! crypttab_contains "$uuid"; then
                    {
                        printf -- 'ENV{ID_PART_ENTRY_UUID}=="*%s*", ' "$uuid"
                        printf -- 'RUN+="%s --settled --unique --onetime ' "$(command -v initqueue)"
                        printf -- '--name systemd-cryptsetup-%%k %s start ' "$(command -v systemctl)"
                        printf -- 'systemd-cryptsetup@%s.service"\n' "$luksname"
                    } >> /etc/udev/rules.d/70-luks.rules.new
                fi
            fi
        done

    elif [ -n "$SERIAL" ]; then
        for serialid in $SERIAL; do

            serialid=${serialid##luks-}
            if luksname=$(_cryptgetargsname "rd.luks.name=$serialid="); then
                luksname="${luksname#$serialid=}"
            else
                luksname="luks-$serialid"
            fi

            if [ -z "$DRACUT_SYSTEMD" ]; then
                {
                    printf -- 'ENV{ID_SERIAL_SHORT}=="*%s*", ' "$serialid"
                    printf -- 'RUN+="%s --settled --unique --onetime ' "$(command -v initqueue)"
                    printf -- '--name cryptroot-ask-%%k %s ' "$(command -v cryptroot-ask)"
                    printf -- '$env{DEVNAME} %s %s"\n' "$luksname" "$tout"
                } >> /etc/udev/rules.d/70-luks.rules.new
            else
                luksname=$(dev_unit_name "$luksname")
                luksname="$(str_replace "$luksname" '\' '\\')"

                if ! crypttab_contains "$serialid"; then
                    {
                        printf -- 'ENV{ID_SERIAL_SHORT}=="*%s*", ' "$serialid"
                        printf -- 'RUN+="%s --settled --unique --onetime ' "$(command -v initqueue)"
                        printf -- '--name systemd-cryptsetup-%%k %s start ' "$(command -v systemctl)"
                        printf -- 'systemd-cryptsetup@%s.service"\n' "$luksname"
                    } >> /etc/udev/rules.d/70-luks.rules.new
                fi
            fi
        done

    elif [ -n "$LUKS" ]; then
        for luksid in $LUKS; do

            luksid=${luksid##luks-}
            if luksname=$(_cryptgetargsname "rd.luks.name=$luksid="); then
                luksname="${luksname#$luksid=}"
            else
                luksname="luks-$luksid"
            fi

            if [ -z "$DRACUT_SYSTEMD" ]; then
                {
                    printf -- 'ENV{ID_FS_TYPE}=="crypto_LUKS", '
                    printf -- 'ENV{ID_FS_UUID}=="*%s*", ' "$luksid"
                    printf -- 'RUN+="%s --settled --unique --onetime ' "$(command -v initqueue)"
                    printf -- '--name cryptroot-ask-%%k %s ' "$(command -v cryptroot-ask)"
                    printf -- '$env{DEVNAME} %s %s"\n' "$luksname" "$tout"
                } >> /etc/udev/rules.d/70-luks.rules.new
            else
                luksname=$(dev_unit_name "$luksname")
                luksname="$(str_replace "$luksname" '\' '\\')"

                if ! crypttab_contains "$luksid"; then
                    {
                        printf -- 'ENV{ID_FS_TYPE}=="crypto_LUKS", '
                        printf -- 'ENV{ID_FS_UUID}=="*%s*", ' "$luksid"
                        printf -- 'RUN+="%s --settled --unique --onetime ' "$(command -v initqueue)"
                        printf -- '--name systemd-cryptsetup-%%k %s start ' "$(command -v systemctl)"
                        printf -- 'systemd-cryptsetup@%s.service"\n' "$luksname"
                    } >> /etc/udev/rules.d/70-luks.rules.new
                fi
            fi

            uuid=$luksid
            while [ "$uuid" != "${uuid#*-}" ]; do uuid=${uuid%%-*}${uuid#*-}; done
            printf -- '[ -e /dev/disk/by-id/dm-uuid-CRYPT-LUKS?-*%s*-* ] || exit 1\n' $uuid \
                >> "$hookdir/initqueue/finished/90-crypt.sh"

            {
                printf -- '[ -e /dev/disk/by-uuid/*%s* ] || ' $luksid
                printf -- 'warn "crypto LUKS UUID "%s" not found"\n' $luksid
            } >> "$hookdir/emergency/90-crypt.sh"
        done
    elif getargbool 0 rd.auto; then
        if [ -z "$DRACUT_SYSTEMD" ]; then
            {
                printf -- 'ENV{ID_FS_TYPE}=="crypto_LUKS", RUN+="%s ' "$(command -v initqueue)"
                printf -- '--unique --settled --onetime --name cryptroot-ask-%%k '
                printf -- '%s $env{DEVNAME} luks-$env{ID_FS_UUID} %s"\n' "$(command -v cryptroot-ask)" "$tout"
            } >> /etc/udev/rules.d/70-luks.rules.new
        else
            {
                printf -- 'ENV{ID_FS_TYPE}=="crypto_LUKS", RUN+="%s ' "$(command -v initqueue)"
                printf -- '--unique --settled --onetime --name crypt-run-generator-%%k '
                printf -- '%s $env{DEVNAME} luks-$env{ID_FS_UUID}"\n' "$(command -v crypt-run-generator)"
            } >> /etc/udev/rules.d/70-luks.rules.new
        fi
    fi

    echo 'LABEL="luks_end"' >> /etc/udev/rules.d/70-luks.rules.new
    mv /etc/udev/rules.d/70-luks.rules.new /etc/udev/rules.d/70-luks.rules
fi
