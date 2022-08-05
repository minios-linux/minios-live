#!/bin/bash
if [ ! -d $1 ]; then
   mkdir -p $1
fi

for file in $1/01-drivers \
   $1/01-firmware \
   $1/02-xorg \
   $1/03-xfce-desktop \
   $1/04-xfce-apps \
   $1/05-browser; do
   if [ -L $file ]; then
      rm $file
   fi
   ln -s ../../scripts/$(basename $file) $file
done
