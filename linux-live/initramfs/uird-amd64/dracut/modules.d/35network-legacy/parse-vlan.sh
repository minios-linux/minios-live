#!/bin/sh
#
# Format:
#	vlan=<vlanname>:<phydevice>
#

parsevlan() {
    local v=${1}:
    set --
    while [ -n "$v" ]; do
        set -- "$@" "${v%%:*}"
        v=${v#*:}
    done

    unset vlanname phydevice
    case $# in
    2)  vlanname=$1; phydevice=$2 ;;
    *)  die "vlan= requires two parameters" ;;
    esac
}

for vlan in $(getargs vlan=); do
    unset vlanname
    unset phydevice
    if [ ! "$vlan" = "vlan" ]; then
        parsevlan "$vlan"
    fi

    echo "phydevice=\"$phydevice\"" > /tmp/vlan.${phydevice}.phy
    {
        echo "vlanname=\"$vlanname\""
        echo "phydevice=\"$phydevice\""
    } > /tmp/vlan.${vlanname}.${phydevice}
done
