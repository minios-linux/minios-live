#!/bin/sh
#
# This hook attempts to load the appropriate thermal modules
# for PowerPC Macs depending on the specific machine you have.

[ -r /proc/cpuinfo ] || exit 0

load_windfarm() {
    local pm_model="$(sed -n '/model/p' /proc/cpuinfo)"
    pm_model="${pm_model##*: }"

    # load quietly and respect the blacklist
    # this way if the modules are for some reason missing, it will
    # still exit successfully and not affect the boot process
    case "$pm_model" in
        PowerMac3,6)             modprobe -b -q therm_windtunnel ;;
        PowerMac7,2|PowerMac7,3) modprobe -b -q windfarm_pm72    ;;
        PowerMac8,1|PowerMac8,2) modprobe -b -q windfarm_pm81    ;;
        PowerMac9,1)             modprobe -b -q windfarm_pm91    ;;
        PowerMac11,2)            modprobe -b -q windfarm_pm112   ;;
        PowerMac12,1)            modprobe -b -q windfarm_pm121   ;;
        RackMac3,1)              modprobe -b -q windfarm_rm31    ;;
        *) ;;
    esac

    return 0
}

load_windfarm
