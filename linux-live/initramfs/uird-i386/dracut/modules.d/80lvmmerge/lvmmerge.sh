#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

do_merge() {
    sed -i -e 's/\(^[[:space:]]*\)locking_type[[:space:]]*=[[:space:]]*[[:digit:]]/\1locking_type = 1/' \
        /etc/lvm/lvm.conf

    systemctl --no-block stop sysroot.mount
    swapoff -a
    umount -R /sysroot

    for tag in $(getargs rd.lvm.mergetags); do
        lvm vgs --noheadings -o vg_name | \
            while read -r vg || [[ -n $vg ]]; do
                unset LVS
                declare -a LVS
                lvs=$(lvm lvs --noheadings -o lv_name "$vg")
                for lv in $lvs; do
                    lvm lvchange -an "$vg/$lv"

                    tags=$(trim "$(lvm lvs --noheadings -o lv_tags "$vg/$lv")")
                    strstr ",${tags}," ",${tag}," || continue

                    if ! lvm lvs --noheadings -o lv_name "${vg}/${lv}_dracutsnap" &>/dev/null; then
                        info "Creating backup ${lv}_dracutsnap of ${vg}/${lv}"
                        lvm lvcreate -pr -s "${vg}/${lv}" --name "${lv}_dracutsnap"
                    fi
                    lvm lvchange --addtag "$tag" "${vg}/${lv}_dracutsnap"

                    info "Merging back ${vg}/${lv} to the original LV"
                    lvm lvconvert --merge "${vg}/${lv}"

                    LVS+=($lv)
                done

                systemctl --no-block stop sysroot.mount
                udevadm settle

                for ((i=0; i < 100; i++)); do
                    lvm vgchange -an "$vg" && break
                    sleep 0.5
                done

                udevadm settle
                lvm vgchange -ay "$vg"
                udevadm settle
                for lv in "${LVS[@]}"; do
                    info "Renaming ${lv}_dracutsnap backup to ${vg}/${lv}"
                    lvm lvrename "$vg" "${lv}_dracutsnap" "${lv}"
                done
                udevadm settle
            done
    done

    systemctl --no-block reset-failed systemd-fsck-root
    systemctl --no-block start systemd-fsck-root
    systemctl --no-block reset-failed sysroot.mount
    systemctl --no-block start sysroot.mount

    for ((i=0; i < 100; i++)); do
        [[ -d /sysroot/dev ]] && break
        sleep 0.5
        systemctl --no-block start sysroot.mount
    done

    if [[ -d /sysroot/restoredev ]]; then
        (
            if cd /sysroot/restoredev; then
                # restore devices and partitions
                for i in *; do
                    target=$(systemd-escape -pu "$i")
                    if ! [[ -b $target ]]; then
                        warn "Not restoring $target, as the device does not exist"
                        continue
                    fi

                    # Just in case
                    umount "$target" &> /dev/null

                    info "Restoring $target"
                    dd if="$i" of="$target" |& vinfo
                done
            fi
        )
        mount -o remount,rw /sysroot
        rm -fr /sysroot/restoredev
    fi
    info "Rebooting"
    reboot
}

if getarg rd.lvm.mergetags; then
    do_merge
fi

