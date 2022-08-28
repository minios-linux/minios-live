#!/bin/sh

# Implement blacklisting for udev-loaded modules

modprobe -b "$@"
