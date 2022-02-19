#!/bin/bash
if [ ! -d $file ]; then
   mkdir -p $1
fi

for file in $1/01-firmware \
   $1/02-xorg \
   $1/03-xfce-desktop \
   $1/04-xfce-apps \
   $1/05-chromium \
   $1/06-virtualbox; do
   if [ -L $file ]; then
      rm $file
   fi
   ln -s ../../scripts/$(basename $file) $file
done
