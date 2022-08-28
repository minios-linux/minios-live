#!/bin/bash
# fetch-liveupdate - fetch an update image for dmsquash-live media.
# this gets called by the "initqueue/online" hook for each network interface
# that comes online.

# no updates requested? we're not needed.
[ -e /tmp/liveupdates.info ] || return 0

command -v getarg >/dev/null || . /lib/dracut-lib.sh
command -v fetch_url >/dev/null || . /lib/url-lib.sh
command -v unpack_img >/dev/null || . /lib/img-lib.sh

read url < /tmp/liveupdates.info

info "fetching live updates from $url"

fetch_url "$url" /tmp/updates.img
if [ $? != 0 ]; then
    warn "failed to fetch update image!"
    warn "url: $url"
    return 1
fi

unpack_img /tmp/updates.img /updates.tmp.$$
if [ $? != 0 ]; then
    warn "failed to unpack update image!"
    warn "url: $url"
    return 1
fi
copytree /updates.tmp.$$ /updates
mv /tmp/liveupdates.info /tmp/liveupdates.done
