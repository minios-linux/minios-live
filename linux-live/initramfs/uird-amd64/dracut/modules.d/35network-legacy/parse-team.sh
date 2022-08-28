#!/bin/sh
#
# Format:
#       team=<teammaster>:<teamslaves>
#
#       teamslaves is a comma-separated list of physical (ethernet) interfaces
#

parseteam() {
    local v=${1}:
    set --
    while [ -n "$v" ]; do
        set -- "$@" "${v%%:*}"
        v=${v#*:}
    done

    case $# in
    2)  teammaster=$1; teamslaves=$(str_replace "$2" "," " ") ;;
    *)  die "team= requires two parameters" ;;
    esac
    return 0
}

for team in $(getargs team); do
    [ "$team" = "team" ] && continue

    unset teammaster
    unset teamslaves

    parseteam "$team" || continue

    echo "teammaster=$teammaster" > /tmp/team.${teammaster}.info
    echo "teamslaves=\"$teamslaves\"" >> /tmp/team.${teammaster}.info

    if ! [ -e /etc/teamd/${teammaster}.conf ]; then
        warn "Team master $teammaster specified, but no /etc/teamd/$teammaster.conf present. Using activebackup."
        mkdir -p /etc/teamd
        printf -- "%s" '{"runner": {"name": "activebackup"}, "link_watch": {"name": "ethtool"}}' > "/etc/teamd/${teammaster}.conf"
    fi
done

