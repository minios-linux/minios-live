#!/bin/sh
# Shutdown script for initramfs. It's automatically started by
# dracut's shutdown hook when system is powering off/rebooting.
# Purpose of this script is to unmount everything cleanly.
#
# Author: Tomas M <http://www.linux-live.org/>
# Author: crims0n <crims0n@minios.dev>

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Detect shutdown type from kernel command line or environment
SHUTDOWN_TYPE="shutdown"
if grep -q "reboot" /proc/cmdline 2>/dev/null || [ "$1" = "reboot" ]; then
   SHUTDOWN_TYPE="reboot"
elif cat /proc/1/cmdline 2>/dev/null | grep -q "reboot"; then
   SHUTDOWN_TYPE="reboot"
fi

detach_free_loops() {
   losetup -a | cut -d : -f 1 | xargs -r -n 1 losetup -d
}

# $1=dir
umount_all() {
   tac /proc/mounts | cut -d " " -f 2 | grep "^$1" | while read LINE; do
      umount "$LINE" 2>/dev/null
      detach_free_loops
   done
}

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Detaching loop devices..."
if command -v mdev >/dev/null 2>&1; then
    mdev -s 2>/dev/null || true
fi
detach_free_loops

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Unmounting union filesystem..."
umount_all /oldroot

# Remember from which device we are started, so we can eject it later
DEVICE="$(cat /proc/mounts | grep -E '/(memory|initramfs/memory)/data' | grep /dev/ | head -n1 | cut -d " " -f 1)"

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Relocating blocking mounts..."
NR=100
tac /proc/mounts | cut -d " " -f 2 | grep "^/oldroot/" | while read LINE; do
   NR=$((NR + 1))
   mkdir -p /move/$NR
   mount --move "$LINE" /move/$NR 2>/dev/null
   umount /oldroot 2>/dev/null
done

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Clearing remaining mounts..."
for i in 1 2 3 4; do
   for d in $(ls -1 /move 2>/dev/null | sort); do
      umount_all /move/$d
   done
done

echo -e "${WHITE}[${GREEN}*${WHITE}]${RESET} Unmounting memory filesystem..."
umount_all /oldroot/run/initramfs/memory
umount_all /oldsys/run/initramfs/memory
umount_all /run/initramfs/memory
umount_all /memory

# Eject CD/DVD if booted from optical media
for i in $(cat /proc/sys/dev/cdrom/info 2>/dev/null | grep "^drive name:" | awk '{print $3}'); do
   if [ "$DEVICE" = "/dev/$i" ]; then
      echo -e "${WHITE}[${YELLOW}!${WHITE}]${RESET} Ejecting optical drive ${CYAN}/dev/$i${RESET}..."
      eject -r /dev/$i 2>/dev/null || eject /dev/$i 2>/dev/null || true
      echo -e "${WHITE}[${YELLOW}!${WHITE}]${RESET} CD/DVD tray will close in 6 seconds..."
      sleep 6
      eject -t /dev/$i 2>/dev/null || true
   fi
done

if [ "$SHUTDOWN_TYPE" = "reboot" ]; then
   echo -e "${WHITE}[${GREEN}OK${WHITE}]${RESET} System prepared for reboot"
else
   echo -e "${WHITE}[${GREEN}OK${WHITE}]${RESET} System prepared for shutdown"
fi
