#!/bin/bash
#
# This module attempts to properly deal with thermal behavior on PowerPC
# based Mac systems, by installing the model-appropriate (when hostonly)
# or all (when not) fan control/thermal kernel modules and loading them
# in a hook.
#
# While this is not strictly necessary for all kernels, particularly
# modular kernels will not autoload those drivers, even once the full
# system is up, which results in the fans spinning up to 100%; this is
# particularly annoying on live systems, where the system takes a while
# to load, so it's best to load the drivers early in initramfs stage.
#
# The behavior of this is inspired by the thermal hook in Debian's
# initramfs-tools, but written for dracut specifically and updated
# for modern kernels (2012+).

# called by dracut
check() {
    local _arch="$(uname -m)"
    # only for PowerPC Macs
    [[ "$_arch" == ppc* && "$_arch" != ppc*le ]] || return 1
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    pmac_model() {
        local pm_model="$(grep model /proc/cpuinfo)"
        echo "${pm_model##*: }"
    }

    # only PowerMac3,6 has a module, special case
    if [[ "$(uname -m)" == ppc ]]; then
        if ! [[ $hostonly ]] || [[ "$(pmac_model)" == "PowerMac3,6" ]]; then
            instmods therm_windtunnel
        fi
        return 0
    fi

    windfarm_modules() {
        if ! [[ $hostonly ]]; then
            # include all drivers when not hostonly
            instmods \
                windfarm_pm72 windfarm_pm81 windfarm_pm91 windfarm_pm112 \
                windfarm_pm121 windfarm_rm31
        else
            # guess model specific module, then install the rest
            case "$(pmac_model)" in
                PowerMac7,2|PowerMac7,3) instmods windfarm_pm72  ;;
                PowerMac8,1|PowerMac8,2) instmods windfarm_pm81  ;;
                PowerMac9,1)             instmods windfarm_pm91  ;;
                PowerMac11,2)            instmods windfarm_pm112 ;;
                PowerMac12,1)            instmods windfarm_pm121 ;;
                RackMac3,1)              instmods windfarm_rm31  ;;
                # no match, so skip installation of the rest
                *) return 1 ;;
            esac
        fi
        return 0
    }

    # hostonly and didn't match a model; skip installing other modules
    windfarm_modules || return 0
    # these are all required by the assorted windfarm_pm*
    instmods \
        windfarm_core windfarm_cpufreq_clamp windfarm_pid \
        windfarm_smu_controls windfarm_smu_sat windfarm_smu_sensors \
        windfarm_fcu_controls windfarm_ad7417_sensor windfarm_max6690_sensor \
        windfarm_lm75_sensor windfarm_lm87_sensor
}

# called by dracut
install() {
    # this will attempt to load the appropriate modules 
    inst_hook pre-udev 99 "$moddir/load-thermal.sh"
}
