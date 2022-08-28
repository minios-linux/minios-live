#!/bin/bash
#
# sas_transport_lun_scan
#
# Selectively enable individual LUNs behind a SAS end device
#
# ACTION=="add", SUBSYSTEM=="sas_transport", ATTR{sas_address}=="sas_addr", \
#    PROGRAM="sas_transport_lun_scan lun"
#

[ -z $DEVPATH ] && exit 1

if [ -n "$1" ] ; then
    LUN=$1
else
    LUN=-
fi
ID=${DEVPATH##*/end_device-}
HOST=${ID%%:*}
CHANNEL=${ID%%-*}
CHANNEL=${CHANNEL#*:}
if [ -f /sys$DEVPATH/scsi_target_id ] ; then
    TARGET=$(cat /sys$DEVPATH/scsi_target_id)
fi
[ -z "$TARGET" ] && exit 1
echo 0 $TARGET $LUN > /sys/class/scsi_host/host$HOST/scan
