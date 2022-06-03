#!/usr/bin/env bash
set -e -o xtrace

function _failure() {
  echo -e "\r\nERROR: bash script [ /opt/install.sh ] failed at line $1: \"$2\""
}
trap '_failure ${LINENO} "$BASH_COMMAND"' ERR

# ############################################################################ #


touch /.minios-live-container
apt-get update -y
apt-get install -y wget sudo debootstrap xorriso genisoimage binutils squashfs-tools grub-pc-bin grub-efi-amd64-bin dosfstools mtools xz-utils liblz4-tool zstd git curl
apt-get clean
find /var/log/ -type f | xargs rm -f
rm -f /var/backups/*
rm -f /var/cache/ldconfig/*
rm -f /var/cache/debconf/*
rm -f /var/cache/fontconfig/*
rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/*.bin
rm -f /var/cache/debconf/*-old
rm -f /var/lib/apt/extended_states
rm -f /var/lib/apt/lists/*Packages*
rm -f /var/lib/apt/lists/*Translation*
rm -f /var/lib/apt/lists/*InRelease
rm -f /var/lib/apt/lists/deb.*
rm -f /var/lib/dpkg/*-old
