#!/bin/sh
#
# Format:
#       bond=<bondname>[:<bondslaves>[:<options>[:<mtu>]]]
#
#       bondslaves is a comma-separated list of physical (ethernet) interfaces
#       options is a comma-separated list on bonding options (modinfo bonding for details) in format compatible with initscripts
#       if options include multi-valued arp_ip_target option, then its values should be separated by semicolon.
#
#       bond without parameters assumes bond=bond0:eth0,eth1:mode=balance-rr
#
#       if the mtu is specified, it will be set on the bond master
#

# We translate list of slaves to space-separated here to make it easier to loop over them in ifup
# Ditto for bonding options
parsebond() {
    local v=${1}:
    set --
    while [ -n "$v" ]; do
        set -- "$@" "${v%%:*}"
        v=${v#*:}
    done

    case $# in
    0)  bondname=bond0; bondslaves="eth0 eth1" ;;
    1)  bondname=$1; bondslaves="eth0 eth1" ;;
    2)  bondname=$1; bondslaves=$(str_replace "$2" "," " ") ;;
    3)  bondname=$1; bondslaves=$(str_replace "$2" "," " "); bondoptions=$(str_replace "$3" "," " ") ;;
    4)  bondname=$1; bondslaves=$(str_replace "$2" "," " "); bondoptions=$(str_replace "$3" "," " "); bondmtu=$4;;
    *)  die "bond= requires zero to four parameters" ;;
    esac
}

# Parse bond for bondname, bondslaves, bondmode, bondoptions and bondmtu
for bond in $(getargs bond=); do
    unset bondname
    unset bondslaves
    unset bondoptions
    unset bondmtu
    if [ "$bond" != "bond" ]; then
        parsebond "$bond"
    fi
    # Simple default bond
    if [ -z "$bondname" ]; then
        bondname=bond0
        bondslaves="eth0 eth1"
    fi
    # Make it suitable for initscripts export
    bondoptions=$(str_replace "$bondoptions" ";" ",")
    echo "bondname=$bondname" > /tmp/bond.${bondname}.info
    echo "bondslaves=\"$bondslaves\"" >> /tmp/bond.${bondname}.info
    echo "bondoptions=\"$bondoptions\"" >> /tmp/bond.${bondname}.info
    echo "bondmtu=\"$bondmtu\"" >> /tmp/bond.${bondname}.info
done
