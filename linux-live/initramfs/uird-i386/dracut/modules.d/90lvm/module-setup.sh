#!/bin/bash

# called by dracut
check() {
    # No point trying to support lvm if the binaries are missing
    require_binaries lvm || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in "${host_fs_types[@]}"; do
            [[ $fs = LVM*_member ]] && return 0
        done
        return 255
    }

    return 0
}

# called by dracut
depends() {
    # We depend on dm_mod being loaded
    echo rootfs-block dm
    return 0
}

# called by dracut
cmdline() {
    local _activated
    declare -A _activated

    for dev in "${!host_fs_types[@]}"; do
        [ -e /sys/block/${dev#/dev/}/dm/name ] || continue
        [ -e /sys/block/${dev#/dev/}/dm/uuid ] || continue
        uuid=$(</sys/block/${dev#/dev/}/dm/uuid)
        [[ "${uuid#LVM-}" == "$uuid" ]] && continue
        dev=$(</sys/block/${dev#/dev/}/dm/name)
        eval $(dmsetup splitname --nameprefixes --noheadings --rows "$dev" 2>/dev/null)
        [[ ${DM_VG_NAME} ]] && [[ ${DM_LV_NAME} ]] || return 1
        if ! [[ ${_activated[${DM_VG_NAME}/${DM_LV_NAME}]} ]]; then
            printf " rd.lvm.lv=%s\n" "${DM_VG_NAME}/${DM_LV_NAME} "
            _activated["${DM_VG_NAME}/${DM_LV_NAME}"]=1
        fi
    done
}

installkernel() {
    hostonly='' instmods dm-snapshot
}

# called by dracut
install() {
    local _i

    inst lvm

    if [[ $hostonly_cmdline == "yes" ]]; then
        local _lvmconf=$(cmdline)
        [[ $_lvmconf ]] && printf "%s\n" "$_lvmconf" >> "${initdir}/etc/cmdline.d/90lvm.conf"
    fi

    inst_rules "$moddir/64-lvm.rules"

    if [[ $hostonly ]] || [[ $lvmconf = "yes" ]]; then
        if [ -f $dracutsysrootdir/etc/lvm/lvm.conf ]; then
            inst_simple -H /etc/lvm/lvm.conf
            # FIXME: near-term hack to establish read-only locking;
            # use command-line lvm.conf editor once it is available
            sed -i -e 's/\(^[[:space:]]*\)locking_type[[:space:]]*=[[:space:]]*[[:digit:]]/\1locking_type = 4/' ${initdir}/etc/lvm/lvm.conf
            sed -i -e 's/\(^[[:space:]]*\)use_lvmetad[[:space:]]*=[[:space:]]*[[:digit:]]/\1use_lvmetad = 0/' ${initdir}/etc/lvm/lvm.conf
        fi

        export LVM_SUPPRESS_FD_WARNINGS=1
        # Also install any files needed for LVM system id support.
        if [ -f $dracutsysrootdir/etc/lvm/lvmlocal.conf ]; then
            inst_simple -H /etc/lvm/lvmlocal.conf
        fi
        eval $(lvm dumpconfig global/system_id_source &>/dev/null)
        if [ "$system_id_source" == "file" ]; then
            eval $(lvm dumpconfig global/system_id_file)
            if [ -f "$system_id_file" ]; then
                inst_simple -H $system_id_file
            fi
        fi
        unset LVM_SUPPRESS_FD_WARNINGS
    fi

    if ! [[ -e ${initdir}/etc/lvm/lvm.conf ]]; then
        mkdir -p "${initdir}/etc/lvm"
        {
            echo 'global {'
            echo 'locking_type = 4'
            echo 'use_lvmetad = 0'
            echo '}'
        } > "${initdir}/etc/lvm/lvm.conf"
    fi

    inst_rules 11-dm-lvm.rules 69-dm-lvm-metad.rules

    # Do not run lvmetad update via pvscan in udev rule  - lvmetad is not running yet in dracut!
    if [[ -f ${initdir}/lib/udev/rules.d/69-dm-lvm-metad.rules ]]; then
        if grep -q SYSTEMD_WANTS ${initdir}/lib/udev/rules.d/69-dm-lvm-metad.rules; then
            sed -i -e 's/^ENV{SYSTEMD_ALIAS}=.*/# No LVM pvscan in dracut - lvmetad is not running yet/' \
                ${initdir}/lib/udev/rules.d/69-dm-lvm-metad.rules
            sed -i -e 's/^ENV{ID_MODEL}=.*//' ${initdir}/lib/udev/rules.d/69-dm-lvm-metad.rules
            sed -i -e 's/^ENV{SYSTEMD_WANTS}=.*//' ${initdir}/lib/udev/rules.d/69-dm-lvm-metad.rules
        else
            sed -i -e 's/.*lvm pvscan.*/# No LVM pvscan for in dracut - lvmetad is not running yet/' \
                ${initdir}/lib/udev/rules.d/69-dm-lvm-metad.rules
        fi
    fi

    # Gentoo ebuild for LVM2 prior to 2.02.63-r1 doesn't install above rules
    # files, but provides the one below:
    inst_rules 64-device-mapper.rules
    # debian udev rules
    inst_rules 56-lvm.rules 60-persistent-storage-lvm.rules

    inst_script "$moddir/lvm_scan.sh" /sbin/lvm_scan
    inst_hook cmdline 30 "$moddir/parse-lvm.sh"

    inst_libdir_file "libdevmapper-event-lvm*.so"

    if [[ $hostonly ]] && type -P lvs &>/dev/null; then
        for dev in "${!host_fs_types[@]}"; do
            [ -e /sys/block/${dev#/dev/}/dm/name ] || continue
            dev=$(</sys/block/${dev#/dev/}/dm/name)
            eval $(dmsetup splitname --nameprefixes --noheadings --rows "$dev" 2>/dev/null)
            [[ ${DM_VG_NAME} ]] && [[ ${DM_LV_NAME} ]] || continue
            case "$(lvs --noheadings -o segtype ${DM_VG_NAME} 2>/dev/null)" in
                *thin*|*cache*|*era*)
                    inst_multiple -o thin_dump thin_restore thin_check thin_repair \
                                  cache_dump cache_restore cache_check cache_repair \
                                  era_check era_dump era_invalidate era_restore
                    break;;
            esac
        done
    fi

    if ! [[ $hostonly ]]; then
        inst_multiple -o thin_dump thin_restore thin_check thin_repair \
                      cache_dump cache_restore cache_check cache_repair \
                      era_check era_dump era_invalidate era_restore
    fi

    dracut_need_initqueue
}
