#!/bin/sh
#
# Preferred format:
#       root=nfs[4]:[server:]path[:options]
#
# This syntax can come from DHCP root-path as well.
#
# Legacy format:
#       root=/dev/nfs nfsroot=[server:]path[,options]
#
# In Legacy root=/dev/nfs mode, if the 'nfsroot' parameter is not given
# on the command line or is empty, the dhcp root-path is used as
# [server:]path[:options] or the default "/tftpboot/%s" will be used.
#
# If server is unspecified it will be pulled from one of the following
# sources, in order:
#       static ip= option on kernel command line
#       DHCP next-server option
#       DHCP server-id option
#       DHCP root-path option
#
# NFSv4 is only used if explicitly requested with nfs4: prefix, otherwise
# NFSv3 is used.
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
 . /lib/nfs-lib.sh

# This script is sourced, so root should be set. But let's be paranoid
[ -z "$root" ] && root=$(getarg root=)
[ -z "$nfsroot" ] && nfsroot=$(getarg nfsroot=)

[ -n "$netroot" ] && oldnetroot="$netroot"

# netroot= cmdline argument must be ignored, but must be used if
# we're inside netroot to parse dhcp root-path
if [ -n "$netroot" ] ; then
    for n in $(getargs netroot=); do
        [ "$n" = "$netroot" ] && break
    done
    if [ "$n" = "$netroot" ]; then
        #warn "Ignoring netroot argument for NFS"
        netroot=$root
    fi
else
    netroot=$root;
fi

# LEGACY: nfsroot= is valid only if root=/dev/nfs
if [ -n "$nfsroot" ] ; then
    # @deprecated
    warn "Argument nfsroot is deprecated and might be removed in a future release. See 'man dracut.kernel' for more information."
    if [ "$(getarg root=)" != "/dev/nfs"  ]; then
        die "Argument nfsroot only accepted for legacy root=/dev/nfs"
    fi
    netroot=nfs:$nfsroot;
fi

case "$netroot" in
    /dev/nfs) netroot=nfs;;
    /dev/*)
        if [ -n "$oldnetroot" ]; then
            netroot="$oldnetroot"
        else
            unset netroot
        fi
	return
	;;
    # LEGACY: root=<server-ip>:/<path
    [0-9]*:/*|[0-9]*\.[0-9]*\.[0-9]*[!:]|/*)
        netroot=nfs:$netroot;;
esac

# Continue if nfs
case "${netroot%%:*}" in
    nfs|nfs4|/dev/nfs);;
    *)
        if [ -n "$oldnetroot" ]; then
            netroot="$oldnetroot"
        else
            unset netroot
        fi
        return
        ;;
esac

# Check required arguments

if nfsdomain=$(getarg rd.nfs.domain -d rd_NFS_DOMAIN); then
    if [ -f /etc/idmapd.conf ]; then
        sed -i -e \
            "s/^[[:space:]#]*Domain[[:space:]]*=.*/Domain = $nfsdomain/g" \
            /etc/idmapd.conf
    fi
    # and even again after the sed, in case it was not yet specified
    echo "Domain = $nfsdomain" >> /etc/idmapd.conf
fi

nfsroot_to_var $netroot
[ "$path" = "error" ] && die "Argument nfsroot must contain a valid path!"

# Set fstype, might help somewhere
fstype=${nfs#/dev/}

# Rewrite root so we don't have to parse this uglyness later on again
netroot="$fstype:$server:$path:$options"

# If we don't have a server, we need dhcp
if [ -z "$server" ] ; then
    DHCPORSERVER="1"
fi;

# Done, all good!
rootok=1

# Shut up init error check or make sure that block parser wont get
# confused by having /dev/nfs[4]
root="$fstype"

echo '[ -e $NEWROOT/proc ]' > $hookdir/initqueue/finished/nfsroot.sh

mkdir -p /var/lib/rpcbind
chown rpc:rpc /var/lib/rpcbind
chmod 770 /var/lib/rpcbind
