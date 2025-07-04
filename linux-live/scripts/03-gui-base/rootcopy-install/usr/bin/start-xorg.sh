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

# Start the X server as the user specified in the $LIVE_USERNAME variable
exec /bin/su --login -c "/usr/bin/startx -- :0 vt7 -ac -nolisten tcp" $LIVE_USERNAME
