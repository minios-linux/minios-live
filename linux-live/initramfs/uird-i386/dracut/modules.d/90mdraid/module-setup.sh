#!/bin/bash

# called by dracut
check() {
    local _rootdev
    # No mdadm?  No mdraid support.
    require_binaries mdadm expr || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for dev in "${!host_fs_types[@]}"; do
            [[ "${host_fs_types[$dev]}" != *_raid_member ]] && continue

            DEVPATH=$(get_devpath_block "$dev")

            for holder in "$DEVPATH"/holders/*; do
                [[ -e "$holder" ]] || continue
                [[ -e "$holder/md" ]] && return 0
                break
            done

        done
        return 255
    }

    return 0
}

# called by dracut
depends() {
    echo rootfs-block
    return 0
}

# called by dracut
installkernel() {
    instmods =drivers/md
}

# called by dracut
cmdline() {
    local _activated dev line UUID
    declare -A _activated

    for dev in "${!host_fs_types[@]}"; do
        [[ "${host_fs_types[$dev]}" != *_raid_member ]] && continue

        UUID=$(
            /sbin/mdadm --examine --export $dev \
                | while read line || [ -n "$line" ]; do
                [[ ${line#MD_UUID=} = $line ]] && continue
                printf "%s" "${line#MD_UUID=} "
            done
        )

        [[ -z "$UUID" ]] && continue

        if ! [[ ${_activated[${UUID}]} ]]; then
            printf "%s" " rd.md.uuid=${UUID}"
            _activated["${UUID}"]=1
        fi

    done
}

# called by dracut
install() {
    local rule rule_path
    inst_multiple cat expr
    inst_multiple -o mdmon
    inst $(command -v partx) /sbin/partx
    inst $(command -v mdadm) /sbin/mdadm

    if [[ $hostonly_cmdline == "yes" ]]; then
        local _raidconf=$(cmdline)
        [[ $_raidconf ]] && printf "%s\n" "$_raidconf" >> "${initdir}/etc/cmdline.d/90mdraid.conf"
    fi

    # <mdadm-3.3 udev rule
    inst_rules 64-md-raid.rules
    # >=mdadm-3.3 udev rules
    inst_rules 63-md-raid-arrays.rules 64-md-raid-assembly.rules
    # remove incremental assembly from stock rules, so they don't shadow
    # 65-md-inc*.rules and its fine-grained controls, or cause other problems
    # when we explicitly don't want certain components to be incrementally
    # assembled
    for rule in 64-md-raid.rules 64-md-raid-assembly.rules; do
        rule_path="${initdir}${udevdir}/rules.d/${rule}"
        [ -f "${rule_path}" ] && sed -i -r \
            -e '/(RUN|IMPORT\{program\})\+?="[[:alpha:]/]*mdadm[[:blank:]]+(--incremental|-I)[[:blank:]]+(--export )?(\$env\{DEVNAME\}|\$tempnode|\$devnode)/d' \
            "${rule_path}"
    done

    inst_rules "$moddir/65-md-incremental-imsm.rules"

    inst_rules "$moddir/59-persistent-storage-md.rules"
    prepare_udev_rules 59-persistent-storage-md.rules

    # guard against pre-3.0 mdadm versions, that can't handle containers
    if ! mdadm -Q -e imsm /dev/null >/dev/null 2>&1; then
        inst_hook pre-trigger 30 "$moddir/md-noimsm.sh"
    fi
    if ! mdadm -Q -e ddf /dev/null >/dev/null 2>&1; then
        inst_hook pre-trigger 30 "$moddir/md-noddf.sh"
    fi

    if [[ $hostonly ]] || [[ $mdadmconf = "yes" ]]; then
        if [ -f $dracutsysrootdir/etc/mdadm.conf ]; then
            inst -H /etc/mdadm.conf
        else
            [ -f $dracutsysrootdir/etc/mdadm/mdadm.conf ] && inst -H /etc/mdadm/mdadm.conf /etc/mdadm.conf
        fi
        if [ -d $dracutsysrootdir/etc/mdadm.conf.d ]; then
            local f
            inst_dir /etc/mdadm.conf.d
            for f in /etc/mdadm.conf.d/*.conf; do
                [ -f "$dracutsysrootdir$f" ] || continue
                inst -H "$f"
            done
        fi
    fi

    inst_hook pre-udev 30 "$moddir/mdmon-pre-udev.sh"
    inst_hook pre-trigger 30 "$moddir/parse-md.sh"
    inst_hook pre-mount 10 "$moddir/mdraid-waitclean.sh"
    inst_hook cleanup 99 "$moddir/mdraid-needshutdown.sh"
    inst_hook shutdown 30 "$moddir/md-shutdown.sh"
    inst_script "$moddir/mdraid-cleanup.sh" /sbin/mdraid-cleanup
    inst_script "$moddir/mdraid_start.sh" /sbin/mdraid_start
    if dracut_module_included "systemd"; then
        if [ -e $dracutsysrootdir$systemdsystemunitdir/mdmon@.service ]; then
            inst_simple $systemdsystemunitdir/mdmon@.service
        fi
        if [ -e $dracutsysrootdir$systemdsystemunitdir/mdadm-last-resort@.service ]; then
            inst_simple $systemdsystemunitdir/mdadm-last-resort@.service
        fi
        if [ -e $dracutsysrootdir$systemdsystemunitdir/mdadm-last-resort@.timer ]; then
            inst_simple $systemdsystemunitdir/mdadm-last-resort@.timer
        fi
    fi
    inst_hook pre-shutdown 30 "$moddir/mdmon-pre-shutdown.sh"
    dracut_need_initqueue
}
