#!/bin/sh

MD_UUID=$(getargs rd.md.uuid -d rd_MD_UUID=)
# normalize the uuid
MD_UUID=$(str_replace "$MD_UUID" "-" "")
MD_UUID=$(str_replace "$MD_UUID" ":" "")

if ( ! [ -n "$MD_UUID" ] && ! getargbool 0 rd.auto ) || ! getargbool 1 rd.md -d -n rd_NO_MD; then
    info "rd.md=0: removing MD RAID activation"
    udevproperty rd_NO_MD=1
else
    # rewrite the md rules to only process the specified raid array
    if [ -n "$MD_UUID" ]; then
        for f in /etc/udev/rules.d/65-md-incremental*.rules; do
            [ -e "$f" ] || continue
            while read line || [ -n "$line" ]; do
                if [ "${line%%UUID CHECK}" != "$line" ]; then
                    for uuid in $MD_UUID; do
                        printf 'ENV{ID_FS_UUID}=="%s", GOTO="md_uuid_ok"\n' "$(expr substr $uuid 1 8)-$(expr substr $uuid 9 4)-$(expr substr $uuid 13 4)-$(expr substr $uuid 17 4)-$(expr substr $uuid 21 12)"
                    done;
                    printf 'IMPORT{program}="/sbin/mdadm --examine --export $tempnode"\n'
                    for uuid in $MD_UUID; do
                        printf 'ENV{MD_UUID}=="%s", GOTO="md_uuid_ok"\n' "$(expr substr $uuid 1 8):$(expr substr $uuid 9 8):$(expr substr $uuid 17 8):$(expr substr $uuid 25 8)"
                    done;
                    printf 'GOTO="md_end"\n'
                    printf 'LABEL="md_uuid_ok"\n'
                else
                    echo "$line"
                fi
            done < "${f}" > "${f}.new"
            mv "${f}.new" "$f"
        done
        for uuid in $MD_UUID; do
            uuid="$(expr substr $uuid 1 8):$(expr substr $uuid 9 8):$(expr substr $uuid 17 8):$(expr substr $uuid 25 8)"
            wait_for_dev "/dev/disk/by-id/md-uuid-${uuid}"
        done
    fi
fi


if [ -e /etc/mdadm.conf ] && getargbool 1 rd.md.conf -d -n rd_NO_MDADMCONF; then
    udevproperty rd_MDADMCONF=1
    rm -f -- $hookdir/pre-pivot/*mdraid-cleanup.sh
fi

if ! getargbool 1 rd.md.conf -d -n rd_NO_MDADMCONF; then
    rm -f -- /etc/mdadm/mdadm.conf /etc/mdadm.conf
    ln -s $(command -v mdraid-cleanup) $hookdir/pre-pivot/31-mdraid-cleanup.sh 2>/dev/null
fi

# noiswmd nodmraid for anaconda / rc.sysinit compatibility
# note nodmraid really means nobiosraid, so we don't want MDIMSM then either
if ! getargbool 1 rd.md.imsm -d -n rd_NO_MDIMSM -n noiswmd -n nodmraid; then
    info "no MD RAID for imsm/isw raids"
    udevproperty rd_NO_MDIMSM=1
fi

# same thing with ddf containers
if ! getargbool 1 rd.md.ddf -n rd_NO_MDDDF -n noddfmd -n nodmraid; then
    info "no MD RAID for SNIA ddf raids"
    udevproperty rd_NO_MDDDF=1
fi

strstr "$(mdadm --help-options 2>&1)" offroot && udevproperty rd_MD_OFFROOT=--offroot
