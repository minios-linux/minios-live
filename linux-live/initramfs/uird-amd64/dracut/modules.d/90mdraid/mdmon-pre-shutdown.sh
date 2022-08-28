#!/bin/sh

_do_mdmon_takeover() {
    local ret
    mdmon --takeover --all
    ret=$?
    [ $ret -eq 0 ] && info "Taking over mdmon processes."
    return $ret
}

if command -v mdmon >/dev/null; then
    _do_mdmon_takeover $1
fi
