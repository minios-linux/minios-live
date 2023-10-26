#!/bin/bash

/usr/sbin/clonezilla -s
/usr/sbin/ocs-live-final-action

#clonezilla leaves these mounted when the program is finished. These need to be umounted.
umount /home/partimag &> /dev/null
umount /tmp/local-dev &> /dev/null
