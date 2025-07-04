#!/bin/sh

# Reading configuration files from filesystem and live-media
set -o allexport
for _FILE in /etc/live/config.conf /etc/live/config.conf.d/*.conf; do
    if [ -e "${_FILE}" ]; then
        . "${_FILE}"
    fi
done
set +o allexport

# Append command line parameters to the LIVE_CONFIG_CMDLINE variable
LIVE_CONFIG_CMDLINE="${LIVE_CONFIG_CMDLINE:+$LIVE_CONFIG_CMDLINE }$(cat /proc/cmdline)"

# Extract the username from the command line parameters
for _PARAMETER in ${LIVE_CONFIG_CMDLINE}; do
    case "${_PARAMETER}" in
    live-config.username=* | username=*)
        LIVE_USERNAME="${_PARAMETER#*username=}"
        ;;
    esac
done

# First, try to gracefully terminate the X session
pkill -TERM -u "$LIVE_USERNAME" Xorg
sleep 1

# If there are still processes left – force kill them
pkill -KILL -u "$LIVE_USERNAME" Xorg
