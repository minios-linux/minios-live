#!/bin/sh

# FIXME: load selinux policy.  this should really be done after we switchroot

rd_load_policy()
{
    # If SELinux is disabled exit now
    getarg "selinux=0" > /dev/null && return 0

    SELINUX="enforcing"
    [ -e "$NEWROOT/etc/selinux/config" ] && . "$NEWROOT/etc/selinux/config"

    # Check whether SELinux is in permissive mode
    permissive=0
    getarg "enforcing=0" > /dev/null
    if [ $? -eq 0 -o "$SELINUX" = "permissive" ]; then
        permissive=1
    fi

    # Attempt to load SELinux Policy
    if [ -x "$NEWROOT/usr/sbin/load_policy" -o -x "$NEWROOT/sbin/load_policy" ]; then
        local ret=0
        local out
        info "Loading SELinux policy"
        mount -o bind /sys $NEWROOT/sys
        # load_policy does mount /proc and /sys/fs/selinux in
        # libselinux,selinux_init_load_policy()
        if [ -x "$NEWROOT/sbin/load_policy" ]; then
            out=$(LANG=C chroot "$NEWROOT" /sbin/load_policy -i 2>&1)
            ret=$?
            info $out
        else
            out=$(LANG=C chroot "$NEWROOT" /usr/sbin/load_policy -i 2>&1)
            ret=$?
            info $out
        fi
        umount $NEWROOT/sys/fs/selinux
        umount $NEWROOT/sys

        if [ "$SELINUX" = "disabled" ]; then
            return 0;
        fi

        if [ $ret -eq 0 -o $ret -eq 2 ]; then
            # If machine requires a relabel, force to permissive mode
            [ -e "$NEWROOT"/.autorelabel ] && LANG=C /usr/sbin/setenforce 0
            mount --rbind /dev "$NEWROOT/dev"
            LANG=C chroot "$NEWROOT" /sbin/restorecon -R /dev
            umount -R "$NEWROOT/dev"
            return 0
        fi

        warn "Initial SELinux policy load failed."
        if [ $ret -eq 3 -o $permissive -eq 0 ]; then
            warn "Machine in enforcing mode."
            warn "Not continuing"
            emergency_shell -n selinux
            exit 1
        fi
        return 0
    elif [ $permissive -eq 0 -a "$SELINUX" != "disabled" ]; then
        warn "Machine in enforcing mode and cannot execute load_policy."
        warn "To disable selinux, add selinux=0 to the kernel command line."
        warn "Not continuing"
        emergency_shell -n selinux
        exit 1
    fi
}

rd_load_policy
