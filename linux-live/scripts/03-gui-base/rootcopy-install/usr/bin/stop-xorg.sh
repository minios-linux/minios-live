#!/bin/sh

# Reading configuration files from filesystem and live-media
set -o allexport
for _FILE in /etc/live/config.conf /etc/live/config.conf.d/*.conf; do
    if [ -e "${_FILE}" ]; then
        . "${_FILE}"
    fi
done
set +o allexport

# First, try to gracefully terminate the X session
pkill -TERM -u "$LIVE_USERNAME" Xorg
sleep 1

# If there are still processes left – force kill them
pkill -KILL -u "$LIVE_USERNAME" Xorg
