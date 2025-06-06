#!/bin/sh

# Library of shell functions to help write live-config components

pkg_is_installed() {
    local package="$1"
    if [ -z "$package" ]; then
        echo "ERROR: pkg_is_installed() needs a package as parameter" >&2
        exit 1
    fi
    if dpkg-query -f'${db:Status-Status}\n' -W $package 2>/dev/null | grep -q ^installed; then
        return 0
    fi
    return 1
}

pkg_test_version() {
    local package="$1"
    local relation="$2"
    local version="$3"
    if [ -z "$package" ] || [ -z "$relation" ] || [ -z "$version" ]; then
        echo "ERROR: pkg_test_version() takes three arguments: <package>, <relation>, <version>" >&2
        exit 1
    fi
    local instver=$(dpkg-query -f'${Version}\n' -W $package 2>/dev/null)
    if [ -z "$instver" ]; then
        echo "ERROR: can't test version of package $package if it's not installed"
        exit 1
    fi
    if dpkg --compare-versions "$instver" "$relation" "$version"; then
        return 0
    fi
    return 1
}

component_was_executed() {
    local component="$1"
    if [ -z "$component" ]; then
        echo "ERROR: component_was_executed() needs a component as parameter" >&2
        exit 1
    fi
    if test -e /var/lib/live/config/$component; then
        return 0
    fi
    return 1
}

is_virtual() {
    local VM_TYPE="$1"
    if [[ -z "$VM_TYPE" ]]; then
        if grep -qEi "(VirtualBox|VMware|KVM|QEMU|Xen|microsoft corporation|Bochs)" /sys/class/dmi/id/product_name 2>/dev/null || grep -qEi "(Oracle|microsoft corporation|Bochs)" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        case "$VM_TYPE" in
        VirtualBox)
            if grep -qEi "VirtualBox" /sys/class/dmi/id/product_name 2>/dev/null || grep -qEi "Oracle" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
                return 0
            fi
            ;;
        VMware)
            if grep -qEi "VMware" /sys/class/dmi/id/product_name 2>/dev/null; then
                return 0
            fi
            ;;
        KVM | QEMU)
            if grep -qEi "(KVM|QEMU)" /sys/class/dmi/id/product_name 2>/dev/null || grep -qEi "Bochs" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
                return 0
            fi
            ;;
        Xen)
            if grep -qEi "Xen" /sys/class/dmi/id/product_name 2>/dev/null; then
                return 0
            fi
            ;;
        Hyper-V)
            if grep -qEi "microsoft corporation" /sys/class/dmi/id/sys_vendor 2>/dev/null && grep -qEi "virtual machine" /sys/class/dmi/id/product_name 2>/dev/null; then
                return 0
            fi
            ;;
        *)
            echo "Usage: is_virtual [VirtualBox|VMware|KVM|QEMU|Xen|Hyper-V]" >&2
            return 1
            ;;
        esac
        return 1
    fi
}

get_device() {
    DEVICE=$(df "$1" | awk 'NR==2 {print $1}')
    echo "${DEVICE}"
}

get_device_name() {
    DEVICE_NAME=$(df "$1" | awk 'NR==2 {print $1}' | awk -F/ '{print $NF}')
    echo "${DEVICE_NAME}"
}

get_filesystem_type() {
    DEVICE=$(df "$1" | awk 'NR==2 {print $1}')
    FS_TYPE=$(blkid -o value -s TYPE "${DEVICE}")
    echo "${FS_TYPE}"
}

get_mount_point() {
    MOUNT_POINT=$(df "$1" | awk 'NR==2 {print $6}')
    echo "${MOUNT_POINT}"
}
