#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence

#Improved Look n Feel Method
cat <<EOF >~/.xsessionrc
export XDG_CURRENT_DESKTOP=XFCE
EOF

#Check if user already logged in.
if [ -n "$(loginctl session-status $(loginctl show-user $USER | sed -n -e "s/Sessions=//p") | grep Leader: | grep -E "gdm|sddm|lightdm")" ]; then
	printf "You are locally logged on.\nTo Remote Connect, logout from local session first." | xmessage -title Warning -buttons Exit -default Exit:1 -center -fg gold -bg black -fn "-*-*-*-r-*--0-250-0-0-p-*-iso8859-1" -file -
	exit 1
fi

# Rely on /etc/pam.d/xrdp-sesman using pam_env to load both
# /etc/environment and /etc/default/locale to initialise the
# locale and the user environment properly.

if test -r /etc/profile; then
	. /etc/profile
fi

if test -r ~/.profile; then
	. ~/.profile
fi

test -x /etc/X11/Xsession && exec /etc/X11/Xsession
exec /bin/sh /etc/X11/Xsession
