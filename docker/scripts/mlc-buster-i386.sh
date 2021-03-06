#!/bin/bash

docker run -d --name mlc-buster-i386 --privileged -v /build:/build \
    -e DISTRIBUTION_TYPE="debian" \
    -e DISTRIBUTION="buster" \
    -e DISTRIBUTION_ARCH="i386" \
    -e DESKTOP_ENVIRONMENT="xfce" \
    -e COMP_TYPE="xz" \
    -e DISTRIBUTION_VARIANT="minbase" \
    -e PACKAGE_VARIANT="standard" \
    -e LOGPATH="/var/log" \
    -e OUTPUT="/dev/stdout" \
    -e BUILD_TEST_ISO="0" \
    -e CREATE_BACKUP="0" \
    -e DEV_SYSTEM="0" \
    -e DEBIAN_FRONTEND_TYPE="noninteractive" \
    -e APT_CMD="apt-get" \
    -e APT_OPTIONS="-y" \
    -e BOOT_TYPE="hybrid" \
    -e UNION_BUILD_TYPE="overlayfs" \
    -e SYSTEMNAME="MiniOS" \
    -e USE_BOOTSTRAP="1" \
    -e USE_ROOTFS="1" \
    local/mlc
