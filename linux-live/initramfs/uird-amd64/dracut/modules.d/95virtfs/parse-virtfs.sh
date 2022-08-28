#!/bin/sh

if [ "${root%%:*}" = "virtfs" ] ; then
    modprobe 9pnet_virtio

    rootok=1
fi
