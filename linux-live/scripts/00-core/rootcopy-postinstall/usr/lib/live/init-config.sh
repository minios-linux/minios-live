#!/bin/sh

# Defaults
LIVE_HOSTNAME="minios"
LIVE_USERNAME="live"
LIVE_USER_FULLNAME="MiniOS Live User"
LIVE_USER_DEFAULT_GROUPS="dialout,cdrom,floppy,audio,video,plugdev,users,fuse,plugdev,netdev,powerdev,scanner,bluetooth,weston-launch,kvm,libvirt,libvirt-qemu,vboxusers,lpadmin,dip,sambashare,docker,wireshark"
export LIVE_HOSTNAME LIVE_USERNAME LIVE_USER_FULLNAME LIVE_USER_DEFAULT_GROUPS

# Reading configuration files from filesystem and live-media
set -o allexport
for _FILE in /etc/live/config.conf /etc/live/config.conf.d/*.conf \
	     /lib/live/mount/medium/live/config.conf /lib/live/mount/medium/live/config.conf.d/*.conf \
	     /lib/live/mount/persistence/*/live/config.conf /lib/live/mount/persistence/*/live/config.conf.d/*.conf \
	     /run/initramfs/memory/data/minios/config.conf /run/initramfs/memory/data/minios/config.conf.d/*.conf
do
	if [ -e "${_FILE}" ]
	then
		. "${_FILE}"
	fi
done
set +o allexport
