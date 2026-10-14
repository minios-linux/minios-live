#!/bin/sh
if [ -d /etc/X11/xinit/xinitrc.d ]; then
    for script in /etc/X11/xinit/xinitrc.d/*; do
        # shellcheck disable=SC1090
        [ ! -x "$script" ] || . "$script"
    done
fi
exec /usr/bin/minios-gnome-session
