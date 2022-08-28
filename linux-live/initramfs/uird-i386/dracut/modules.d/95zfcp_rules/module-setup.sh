#!/bin/bash

# called by dracut
cmdline() {
    is_zfcp() {
        local _dev=$1
        local _devpath=$(cd -P /sys/dev/block/$_dev ; echo $PWD)
        local _sdev _scsiid _hostno _lun _wwpn _ccw _port_type
        local _allow_lun_scan _is_npiv

        _allow_lun_scan=$(cat /sys/module/zfcp/parameters/allow_lun_scan)
        [ "${_devpath#*/sd}" == "$_devpath" ] && return 1
        _sdev="${_devpath%%/block/*}"
        [ -e ${_sdev}/fcp_lun ] || return 1
        _scsiid="${_sdev##*/}"
        _hostno="${_scsiid%%:*}"
        [ -d /sys/class/fc_host/host${_hostno} ] || return 1
        _port_type=$(cat /sys/class/fc_host/host${_hostno}/port_type)
        case "$_port_type" in
            NPIV*)
                _is_npiv=1
                ;;
        esac
        _ccw=$(cat ${_sdev}/hba_id)
        if [ "$_is_npiv" ] && [ "$_allow_lun_scan" = "Y" ] ; then
            echo "rd.zfcp=${_ccw}"
        else
            _lun=$(cat ${_sdev}/fcp_lun)
            _wwpn=$(cat ${_sdev}/wwpn)
            echo "rd.zfcp=${_ccw},${_wwpn},${_lun}"
        fi
        return 0
    }
    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for_each_host_dev_and_slaves_all is_zfcp
    } | sort | uniq
}

# called by dracut
check() {
    local _arch=${DRACUT_ARCH:-$(uname -m)}
    local _ccw
    [ "$_arch" = "s390" -o "$_arch" = "s390x" ] || return 1
    require_binaries /usr/lib/udev/collect || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        found=0
        for _ccw in /sys/bus/ccw/devices/*/host* ; do
            [ -d "$_ccw" ] || continue
            found=$(($found+1));
        done
        [ $found -eq 0 ] && return 255
    }
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_multiple /usr/lib/udev/collect
    inst_hook cmdline 30 "$moddir/parse-zfcp.sh"
    if [[ $hostonly_cmdline == "yes" ]] ; then
        local _zfcp

        for _zfcp in $(cmdline) ; do
            printf "%s\n" "$_zfcp" >> "${initdir}/etc/cmdline.d/94zfcp.conf"
        done
    fi
    if [[ $hostonly ]] ; then
        inst_rules_wildcard 51-zfcp-*.rules
        inst_rules_wildcard 41-s390x-zfcp-*.rules
    fi
}
