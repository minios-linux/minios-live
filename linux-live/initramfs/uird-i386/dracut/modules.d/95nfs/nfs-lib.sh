#!/bin/sh

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
. /lib/net-lib.sh

# TODO: make these things not pollute the calling namespace

# nfs_to_var NFSROOT [NETIF]
# use NFSROOT to set $nfs, $server, $path, and $options.
# NFSROOT is something like: nfs[4]:<server>:/<path>[:<options>|,<options>]
# NETIF is used to get information from DHCP options, if needed.
nfs_to_var() {
    # Unfortunately, there's multiple styles of nfs "URL" in use, so we need
    # extra functions to parse them into $nfs, $server, $path, and $options.
    # FIXME: local netif=${2:-$netif}?
    case "$1" in
        nfs://*) rfc2224_nfs_to_var "$1" ;;
        nfs:*[*) anaconda_nfsv6_to_var "$1" ;;
        nfs:*:*:/*) anaconda_nfs_to_var "$1" ;;
        *) nfsroot_to_var "$1" ;;
    esac
    # if anything's missing, try to fill it in from DHCP options
    if [ -z "$server" ] || [ -z "$path" ]; then nfsroot_from_dhcp $2; fi
    # if there's a "%s" in the path, replace it with the hostname/IP
    if strstr "$path" "%s"; then
        local node=""
        read node < /proc/sys/kernel/hostname
        [ "$node" = "(none)" ] && node=$(get_ip $2)
        path=${path%%%s*}$node${path#*%s} # replace only the first %s
    fi
}

# root=nfs:[<server-ip>:]<root-dir>[:<nfs-options>]
# root=nfs4:[<server-ip>:]<root-dir>[:<nfs-options>]
nfsroot_to_var() {
    # strip nfs[4]:
    local arg="$@:"
    nfs="${arg%%:*}"
    arg="${arg##$nfs:}"

    # check if we have a server
    if strstr "$arg" ':/' ; then
        server="${arg%%:/*}"
        arg="/${arg##*:/}"
    fi

    path="${arg%%:*}"

    # rest are options
    options="${arg##$path}"
    # strip leading ":"
    options="${options##:}"
    # strip  ":"
    options="${options%%:}"

    # Does it really start with '/'?
    [ -n "${path%%/*}" ] && path="error";

    #Fix kernel legacy style separating path and options with ','
    if [ "$path" != "${path#*,}" ] ; then
        options=${path#*,}
        path=${path%%,*}
    fi
}

# RFC2224: nfs://<server>[:<port>]/<path>
rfc2224_nfs_to_var() {
    nfs="nfs"
    server="${1#nfs://}"
    path="/${server#*/}"
    server="${server%%/*}"
    server="${server%%:}" # anaconda compat (nfs://<server>:/<path>)
    local port="${server##*:}"
    [ "$port" != "$server" ] && options="port=$port"
}

# Anaconda-style path with options: nfs:<options>:<server>:/<path>
# (without mount options, anaconda is the same as dracut)
anaconda_nfs_to_var() {
    nfs="nfs"
    options="${1#nfs:}"
    server="${options#*:}"
    server="${server%:/*}"
    options="${options%%:*}"
    path="/${1##*:/}"
}

# IPv6 nfs path will be treated separately
anaconda_nfsv6_to_var() {
    nfs="nfs"
    path="$1"
    options="${path#*:/}"
    path="/${options%%:*}"
    server="${1#*nfs:}"
    if str_starts $server '['; then
        server="${server%:/*}"
        options="${options#*:*}"
    else
        server="${server%:/*}"
        options="${server%%:*}"
        server="${server#*:}"
    fi
}

# nfsroot_from_dhcp NETIF
# fill in missing server/path from DHCP options.
nfsroot_from_dhcp() {
    local f
    for f in /tmp/net.$1.override /tmp/dhclient.$1.dhcpopts; do
        [ -f $f ] && . $f
    done
    [ -n "$new_root_path" ] && nfsroot_to_var "$nfs:$new_root_path"
    [ -z "$path" ] && [ "$(getarg root=)" = "/dev/nfs" ] && path=/tftpboot/%s
    [ -z "$server" ] && server=$srv
    [ -z "$server" ] && server=$new_dhcp_server_identifier
    [ -z "$server" ] && server=$new_next_server
    [ -z "$server" ] && server=${new_root_path%%:*}
}

# Look through $options, fix "rw"/"ro", move "lock"/"nolock" to $nfslock
munge_nfs_options() {
    local f="" flags="" nfsrw="ro" OLDIFS="$IFS"
    IFS=,
    for f in $options; do
        case $f in
            ro|rw) nfsrw=$f ;;
            lock|nolock) nfslock=$f ;;
            *) flags=${flags:+$flags,}$f ;;
        esac
    done
    IFS="$OLDIFS"

    # Override rw/ro if set on cmdline
    getarg ro >/dev/null && nfsrw=ro
    getarg rw >/dev/null && nfsrw=rw

    options=$nfsrw${flags:+,$flags}
}

# mount_nfs NFSROOT MNTDIR [NETIF]
mount_nfs() {
    local nfsroot="$1" mntdir="$2" netif="$3"
    local nfs="" server="" path="" options=""
    nfs_to_var "$nfsroot" $netif
    munge_nfs_options
    if [ "$nfs" = "nfs4" ]; then
        options=$options${nfslock:+,$nfslock}
    else
        # NFSv{2,3} doesn't support using locks as it requires a helper to
        # transfer the rpcbind state to the new root
        [ "$nfslock" = "lock" ] \
            && warn "Locks unsupported on NFSv{2,3}, using nolock" 1>&2
        options=$options,nolock
    fi
    mount -t $nfs -o$options "$server:$path" "$mntdir"
}
