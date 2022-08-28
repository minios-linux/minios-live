#!/bin/sh

# nodmraid for anaconda / rc.sysinit compatibility
if ! getargbool 1 rd.dm -d -n rd_NO_DM || getarg "rd.dm=0" -d nodmraid; then
    info "rd.dm=0: removing DM RAID activation"
    udevproperty rd_NO_DM=1
fi

if  ! command -v mdadm >/dev/null \
    || ! getargbool 1 rd.md.imsm -d -n rd_NO_MDIMSM -n noiswmd \
    || ! getargbool 1 rd.md -d -n rd_NO_MD; then
    info "rd.md.imsm=0: no MD RAID for imsm/isw raids"
    udevproperty rd_NO_MDIMSM=1
fi

if  ! command -v mdadm >/dev/null \
    || ! getargbool 1 rd.md.ddf -n rd_NO_MDDDF -n noddfmd \
    || ! getargbool 1 rd.md -d -n rd_NO_MD; then
    info "rd.md.ddf=0: no MD RAID for SNIA ddf raids"
    udevproperty rd_NO_MDDDF=1
fi

DM_RAIDS=$(getargs rd.dm.uuid -d rd_DM_UUID=)

if [ -z "$DM_RAIDS" ] && ! getargbool 0 rd.auto; then
    udevproperty rd_NO_DM=1
fi
