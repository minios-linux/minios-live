#!/bin/sh
#
# System boot configuration script (POSIX sh).
# Author: crims0n <https://minios.dev>
#

CONFIG="/etc/live/config.conf"
CMDLINE="$(cat /proc/cmdline)"

# ======= Functions =======

set_log() {
    mkdir -p /var/log/minios
    mkfifo /tmp/minios-boot.pipe
    tee </tmp/minios-boot.pipe /var/log/minios/minios-boot.log &
    exec >/tmp/minios-boot.pipe 2>&1

    case "${LIVE_CONFIG_DEBUG}" in
    true)
        set -x
        ;;
    esac
}

echo_green_star() {
    printf '\033[0;32m*\033[0;39m '
}

echo_red_star() {
    printf '\033[0;31m*\033[0;39m '
}

echo_white_star() {
    printf '\033[1;37m*\033[0;39m '
}

read_config() {
    CFGFILE=$1
    shift
    if [ ! -r "$CFGFILE" ]; then
        echo_red_star
        echo "$CFGFILE is either not a file or not readable!"
        exit 1
    fi

    for KEY in "$@"; do
        VAL=$(sed -n "s/^${KEY}=[\"']?\(.*\)[\"']?$/\1/p" "$CFGFILE")
        if [ -n "$VAL" ]; then
            eval "$KEY=\"$VAL\""
        fi
    done
}

read_cmdline() {
    for i in "$@"; do
        case $i in
        live-config.username=* | username=*)
            LIVE_USERNAME="${i#*=}"
            ;;
        live-config.debug | debug)
            LIVE_CONFIG_DEBUG="true"
            ;;
        default-target=*)
            DEFAULT_TARGET="${i#*=}"
            ;;
        enable-services=*)
            ENABLE_SERVICES="${i#*=}"
            ;;
        disable-services=*)
            DISABLE_SERVICES="${i#*=}"
            ;;
        esac
    done
}

set_default_target() {
    if [ -z "$DEFAULT_TARGET" ] && [ -r "$CONFIG" ]; then
        read_config "$CONFIG" DEFAULT_TARGET
    fi
    if [ -z "$DEFAULT_TARGET" ]; then
        DEFAULT_TARGET=graphical.target
    fi

    if [ -n "$TEXT_MODE" ]; then
        DEFAULT_TARGET=multi-user.target
    fi

    if ! systemctl set-default "$DEFAULT_TARGET" >/dev/null 2>&1; then
        echo_red_star
        printf 'Failed to set default target: \033[31m%s\033[0m\n' "$DEFAULT_TARGET"
        return 1
    fi
}

manage_services() {
    ACTION=$1
    if [ "$ACTION" = "enable" ]; then
        VARNAME=ENABLE_SERVICES
    elif [ "$ACTION" = "disable" ]; then
        VARNAME=DISABLE_SERVICES
    else
        echo_red_star
        printf 'Invalid action: \033[31m%s\033[0m\n' "$ACTION"
        return 1
    fi

    LIST=$(eval echo "\$$VARNAME")
    if [ -z "$LIST" ] && [ -r "$CONFIG" ]; then
        read_config "$CONFIG" "$VARNAME"
        LIST=$(eval echo "\$$VARNAME")
    fi

    if [ -n "$LIST" ]; then
        OLDIFS=$IFS
        IFS=','
        for SVC in $LIST; do
            if systemctl "$ACTION" "$SVC" >/dev/null 2>&1; then
                echo_green_star
                printf 'Successfully %sd service: \033[32m%s\033[0m\n' "$ACTION" "$SVC"
            else
                echo_red_star
                printf 'Failed to %sd service: \033[31m%s\033[0m\n' "$ACTION" "$SVC"
            fi
        done
        IFS=$OLDIFS
    fi
}

set_autologin() {
    if [ -z "$LIVE_USERNAME" ] && [ -r "$CONFIG" ]; then
        read_config "$CONFIG" LIVE_USERNAME
    fi

    if [ -f /usr/lib/systemd/system/xorg.service ]; then
        cat >/usr/lib/systemd/system/xorg.service <<EOF
[Unit]
Description=X-Window
ConditionKernelCommandLine=!text
ConditionKernelCommandLine=!live-config.nox11autologin
ConditionKernelCommandLine=!nox11autologin
ConditionKernelCommandLine=!live-config.noautologin
ConditionKernelCommandLine=!noautologin
After=systemd-user-sessions.service

[Service]
ExecStart=/bin/su --login -c "/usr/bin/startx -- :0 vt7 -ac -nolisten tcp" "$LIVE_USERNAME"

[Install]
WantedBy=graphical.target
EOF
    fi

    if command -v x11vnc >/dev/null 2>&1 && [ -f /usr/lib/systemd/system/x11vnc.service ]; then
        sed -i "s,-auth guess,-auth /home/$LIVE_USERNAME/.Xauthority,g" /usr/lib/systemd/system/x11vnc.service
    fi
}

# ======= Main =======

set_log
read_cmdline "$CMDLINE"
set_default_target
manage_services enable
manage_services disable
set_autologin

rm -f /tmp/minios-boot.pipe
