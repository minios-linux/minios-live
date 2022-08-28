#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# called by dracut
cmdline() {
    get_lunmask() {
        local _dev=$1
        local _devpath=$(cd -P /sys/dev/block/$_dev ; echo $PWD)
        local _sdev _lun _rport _end_device _classdev _wwpn _sas_address

        [ "${_devpath#*/sd}" == "$_devpath" ] && return 1
        _sdev="${_devpath%%/block/*}"
        _lun="${_sdev##*:}"
        # Check for FibreChannel
        _rport="${_devpath##*/rport-}"
        if [ "$_rport" != "$_devpath" ] ; then
            _rport="${_rport%%/*}"
            _classdev="/sys/class/fc_remote_ports/rport-${_rport}"
            [ -d "$_classdev" ] || return 1
            _wwpn=$(cat ${_classdev}/port_name)
            echo "rd.lunmask=fc,${_wwpn},${_lun}"
            return 0
        fi
        # Check for SAS
        _end_device="${_devpath##*/end_device-}"
        if [ "$_end_device" != "$_devpath" ] ; then
            _end_device="${_end_device%%/*}"
            _classdev="/sys/class/sas_device/end_device-${_end_device}"
            [ -e "$_classdev" ] || return 1
            _sas_address=$(cat ${_classdev}/sas_address)
            echo "rd.lunmask=sas,${_sas_address},${_lun}"
            return 0
        fi
        return 1
    }
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for_each_host_dev_and_slaves_all get_lunmask
    } | sort | uniq
}

# called by dracut
check() {
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        [ -w /sys/module/scsi_mod/parameters/scan ] || return 255
        scan_type=$(cat /sys/module/scsi_mod/parameters/scan)
        [ "$scan_type" = "manual" ] && return 0
        return 255
    }
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_script "$moddir/fc_transport_scan_lun.sh" /usr/lib/udev/fc_transport_scan_lun.sh
    inst_script "$moddir/sas_transport_scan_lun.sh" /usr/lib/udev/sas_transport_scan_lun.sh
    inst_hook cmdline 30 "$moddir/parse-lunmask.sh"
    if [[ $hostonly_cmdline == "yes" ]] ; then
        local _lunmask

        for _lunmask in $(cmdline) ; do
            printf "%s\n" "$_lunmask" >> "${initdir}/etc/cmdline.d/95lunmask.conf"
        done
    fi
}
