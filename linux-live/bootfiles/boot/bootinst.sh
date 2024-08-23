#!/bin/sh
# Setup booting from disk (USB or harddrive)
# Requires: fdisk, df, tail, tr, cut, dd, sed
# If this script is placed on a fat32 (vfat) partition, 
#                   run it with `sudo bash bootinst.sh`

# change working directory to dir from which we are started
CWD="$(pwd)"
BOOT="$(dirname "$0")"
cd "$BOOT"

# find out device and mountpoint
PART="$(df . | tail -n 1 | tr -s " " | cut -d " " -f 1)"
DEV="$(echo "$PART" | sed -r "s:[0-9]+\$::" | sed -r "s:([0-9])[a-z]+\$:\\1:i")"   #"

ARCH=$(uname -m)

if ! [ -w "$DEV" ]; then
    echo "You have no permissions to write to ${DEV}."
    echo "You should run this script with sudo."
    exit 1
fi

echo "MiniOS will be installed to:"

echo "    Target device:   " $DEV
echo "    Target partition:" $PART
echo "    CPU architecture:" $ARCH

echo "If this is what you want, press ENTER to continue."
echo "If this is incorrect, press Ctrl+C to abort."
read r

echo "Beginning installation..."

if [ "$ARCH" = "x86_64" ]; then 
    ARCH=64; 
    EXTLINUX=extlinux.x$ARCH
    /lib64/ld-linux-x86-64.so.2 ./"$EXTLINUX" --install "$BOOT"
else 
    ARCH=32; 
    EXTLINUX=extlinux.x$ARCH
    /lib/ld-linux.so.2 ./"$EXTLINUX" --install "$BOOT"
fi

if [ $? -ne 0 ]; then
   echo "Error installing boot loader."
   echo "Read the errors above and press enter to exit..."
   read junk
   exit 1
fi


if [ "$DEV" != "$PART" ]; then
   # Setup MBR on the first block
   dd bs=440 count=1 conv=notrunc if="$BOOT/mbr.bin" of="$DEV" 2>/dev/null

   # Toggle a bootable flag
   PART="$(echo "$PART" | sed -r "s:.*[^0-9]::")"
   (
      fdisk -l "$DEV" | fgrep "*" | fgrep "$DEV" | cut -d " " -f 1 \
        | sed -r "s:.*[^0-9]::" | xargs -I '{}' echo -ne "a\n{}\n"
      echo a
      echo $PART
      echo w
   ) | fdisk $DEV >/dev/null 2>&1
fi

# UEFI boot loader
cp -r "EFI" "$BOOT/../../"

echo "Boot installation finished."

cd "$CWD"
