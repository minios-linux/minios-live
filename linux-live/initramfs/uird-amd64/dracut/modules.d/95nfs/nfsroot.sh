#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
. /lib/nfs-lib.sh

[ "$#" = 3 ] || exit 1

# root is in the form root=nfs[4]:[server:]path[:options], either from
# cmdline or dhcp root-path
netif="$1"
root="$2"
NEWROOT="$3"

nfs_to_var $root $netif
[ -z "$server" ] && die "Required parameter 'server' is missing"

mount_nfs $root $NEWROOT $netif && { [ -e /dev/root ] || ln -s null /dev/root ; [ -e /dev/nfs ] || ln -s null /dev/nfs; }

[ -f $NEWROOT/etc/fstab ] && cat $NEWROOT/etc/fstab > /dev/null

# inject new exit_if_exists
echo 'settle_exit_if_exists="--exit-if-exists=/dev/root"; rm -- "$job"' > $hookdir/initqueue/nfs.sh
# force udevsettle to break
> $hookdir/initqueue/work

need_shutdown
