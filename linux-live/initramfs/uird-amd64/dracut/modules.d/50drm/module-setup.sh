#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    local _modname
    # Include KMS capable drm drivers

    if [[ "${DRACUT_ARCH:-$(uname -m)}" == arm* || "${DRACUT_ARCH:-$(uname -m)}" == aarch64 ]]; then
        # arm/aarch64 specific modules needed by drm
        instmods \
            "=drivers/gpu/drm/i2c" \
            "=drivers/gpu/drm/panel" \
            "=drivers/gpu/drm/bridge" \
            "=drivers/video/backlight" \
            ${NULL}
    fi

    instmods amdkfd hyperv_fb "=drivers/pwm"

    # if the hardware is present, include module even if it is not currently loaded,
    # as we could e.g. be in the installer; nokmsboot boot parameter will disable
    # loading of the driver if needed
    if [[ $hostonly ]]; then
        for i in /sys/bus/{pci/devices,virtio/devices,soc/devices/soc?}/*/modalias; do
            [[ -e $i ]] || continue
            if hostonly="" dracut_instmods --silent -s "drm_crtc_init" -S "iw_handler_get_spy" $(<$i); then
                if strstr "$(modinfo -F filename $(<$i) 2>/dev/null)" radeon.ko; then
                    hostonly='' instmods amdkfd
                fi
            fi
        done
    else
        dracut_instmods -o -s "drm_crtc_init|drm_dev_register" "=drivers/gpu/drm" "=drivers/staging"
    fi
}
