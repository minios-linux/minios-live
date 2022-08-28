#!/bin/sh
SQUASH_MNT_REC=/squash/mounts
SQUASH_MNTS=( )

while read mnt; do
    SQUASH_MNTS+=( "$mnt" )
done <<< "$(cat $SQUASH_MNT_REC)"

umount --lazy -- ${SQUASH_MNTS[@]}
