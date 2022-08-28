SUBSYSTEM!="block", GOTO="dm_end"
ACTION!="add|change", GOTO="dm_end"
# Also don't process disks that are slated to be a multipath device
ENV{DM_MULTIPATH_DEVICE_PATH}=="1", GOTO="dm_end"

KERNEL!="dm-[0-9]*", GOTO="dm_end"
ACTION=="add", GOTO="dm_end"
IMPORT{program}="/sbin/dmsetup info -c --nameprefixes --unquoted --rows --noheadings -o name,uuid,suspended,readonly,major,minor,open,tables_loaded,names_using_dev -j%M -m%m"
ENV{DM_NAME}!="?*", GOTO="dm_end"
ENV{DM_UDEV_DISABLE_OTHER_RULES_FLAG}=="1", GOTO="dm_end"
ENV{DM_UUID}=="CRYPT-TEMP-?*", GOTO="dm_end"
ENV{DM_UUID}!="?*", ENV{DM_NAME}=="temporary-cryptsetup-?*", GOTO="dm_end"
IMPORT BLKID

LABEL="dm_end"
