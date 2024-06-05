#!/bin/bash
if [ ! -d $1 ]; then
   mkdir -p $1
fi

for file in $1/00-minios \
   $1/01-kernel \
   $1/02-firmware \
   $1/03-xorg \
   $1/04-xfce-desktop \
   $1/05-xfce-apps \
   $1/06-software \
   $1/07-firefox; do
   if [ -L $file ]; then
      rm $file
   fi
   ln -s ../../scripts/$(basename $file) $file
done
