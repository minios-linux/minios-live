#!/bin/sh

type incol2 >/dev/null 2>&1 || . /lib/dracut-lib.sh

[ -f /tmp/nfs.rpc_pipefs_path ] && rpcpipefspath=`cat /tmp/nfs.rpc_pipefs_path`
[ -z "$rpcpipefspath" ] && rpcpipefspath=var/lib/nfs/rpc_pipefs

pid=$(pidof rpc.statd)
[ -n "$pid" ] && kill $pid

pid=$(pidof rpc.idmapd)
[ -n "$pid" ] && kill $pid

pid=$(pidof rpcbind)
[ -n "$pid" ] && kill $pid

if incol2 /proc/mounts /var/lib/nfs/rpc_pipefs; then
    # try to create the destination directory
    [ -d $NEWROOT/$rpcpipefspath ] || \
        mkdir -m 0755 -p $NEWROOT/$rpcpipefspath 2>/dev/null

    if [ -d $NEWROOT/$rpcpipefspath ]; then
        # mount --move does not seem to work???
        mount --bind /var/lib/nfs/rpc_pipefs $NEWROOT/$rpcpipefspath
        umount /var/lib/nfs/rpc_pipefs 2>/dev/null
    else
        umount /var/lib/nfs/rpc_pipefs 2>/dev/null
    fi
fi

