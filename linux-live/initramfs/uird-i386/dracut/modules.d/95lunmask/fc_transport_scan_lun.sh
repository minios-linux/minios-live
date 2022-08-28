#!/bin/bash
#
# fc_transport_lun_scan
#
# Selectively enable individual LUNs behind an FC remote port
#
# ACTION=="add", SUBSYSTEM=="fc_transport", ATTR{port_name}=="wwpn", \
#    PROGRAM="fc_transport_lun_scan lun"
#

[ -z $DEVPATH ] && exit 1

if [ -n "$1" ] ; then
    LUN=$1
else
    LUN=-
fi
ID=${DEVPATH##*/rport-}
HOST=${ID%%:*}
CHANNEL=${ID%%-*}
CHANNEL=${CHANNEL#*:}
if [ -f /sys$DEVPATH/scsi_target_id ] ; then
    TARGET=$(cat /sys$DEVPATH/scsi_target_id)
fi
[ -z "$TARGET" ] && exit 1
echo $CHANNEL $TARGET $LUN > /sys/class/scsi_host/host$HOST/scan
