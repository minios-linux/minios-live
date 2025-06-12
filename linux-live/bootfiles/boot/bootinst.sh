#!/bin/sh
# Setup booting from disk (USB or harddrive)
# Requires: fdisk, df, tail, tr, cut, dd, sed

# Check for root permissions
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please rerun with sudo or as root user."
  exit 1
fi

# change working directory to dir from which we are started
CWD="$(pwd)"
BOOT="$(dirname "$0")"
cd "$BOOT"

# find out device and mountpoint
PART="$(df . | tail -n 1 | tr -s " " | cut -d " " -f 1)"
DEV="$(echo "$PART" | sed -r 's:[0-9]+\$::' | sed -r 's:([0-9])[a-z]+\$:\\1:i')"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH=64; else ARCH=32; fi
EXTLINUX=extlinux.x$ARCH

# Check if EXTLINUX is executable, if not, make it executable
if [ ! -x "./$EXTLINUX" ]; then
   mount -o remount,exec "$DEV" >/dev/null 2>&1
   chmod a+x "./$EXTLINUX" >/dev/null 2>&1
fi

# If still not executable, copy to extlinux.exe
if [ ! -x "./$EXTLINUX" ]; then
   cp -f "./$EXTLINUX" ./extlinux.exe >/dev/null 2>&1
   EXTLINUX=extlinux.exe
fi

./"$EXTLINUX" --install "$BOOT" >/dev/null 2>&1

if [ $? -ne 0 ]; then
   echo "$EXTLINUX failed, trying fallback from /tmp..."
   cp -f "./$EXTLINUX" /tmp/"$EXTLINUX" >/dev/null 2>&1
   chmod a+x /tmp/"$EXTLINUX" >/dev/null 2>&1
   /tmp/"$EXTLINUX" --install "$BOOT" >/dev/null 2>&1
   if [ $? -ne 0 ]; then
       echo "Error installing boot loader."
       echo "Read the errors above and press enter to exit..."
       read junk
       exit 1
   else
       rm -f /tmp/"$EXTLINUX"
       echo "Boot loader installation succeeded."
   fi
fi

if [ "$DEV" != "$PART" ]; then
   # Setup MBR on the first block
   dd bs=440 count=1 conv=notrunc if="$BOOT/mbr.bin" of="$DEV" 2>/dev/null

   # Toggle a bootable flag
   PART="$(echo "$PART" | sed -r 's:.*[^0-9]::')"
   (
      fdisk -l "$DEV" | fgrep "*" | fgrep "$DEV" | cut -d ' ' -f 1 |
         sed -r 's:.*[^0-9]::' | xargs -I '{}' echo -ne "a\n{}\n"
      echo a
      echo $PART
      echo w
   ) | fdisk "$DEV" >/dev/null 2>&1
fi

# UEFI boot loader
cp -r "EFI" "$BOOT/../../"

echo "Boot installation finished."

# Remove temporary file
if [ -f ./extlinux.exe ]; then
   rm -f ./extlinux.exe
fi

cd "$CWD"
