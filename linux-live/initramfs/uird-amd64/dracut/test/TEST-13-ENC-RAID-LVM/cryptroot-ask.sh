#!/bin/sh

[ -b /dev/mapper/$2 ] && exit 0
printf test >/keyfile
/sbin/cryptsetup luksOpen $1 $2 </keyfile

