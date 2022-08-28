#!/bin/sh

if resume=$(getarg resume=) && ! getarg noresume; then
    export resume
    echo "$resume" >/.resume
else
    unset resume
fi

case "$resume" in
    LABEL=*) \
        resume="$(echo $resume | sed 's,/,\\x2f,g')"
        resume="/dev/disk/by-label/${resume#LABEL=}" ;;
    UUID=*) \
        resume="/dev/disk/by-uuid/${resume#UUID=}" ;;
    PARTUUID=*) \
        resume="/dev/disk/by-partuuid/${resume#PARTUUID=}" ;;
    PARTLABEL=*) \
        resume="/dev/disk/by-partlabel/${resume#PARTLABEL=}" ;;
esac

if splash=$(getarg splash=); then
    export splash
else
    unset splash
fi

case "$splash" in
    quiet )
        a_splash="-P splash=y"
    ;;
    * )
        a_splash="-P splash=n"
    ;;
esac


if ! getarg noresume; then
    if [ -n "$resume" ]; then
        wait_for_dev /dev/resume

        {
            printf "KERNEL==\"%s\", ACTION==\"add|change\", SYMLINK+=\"resume\"\n" \
                ${resume#/dev/};
            printf "SYMLINK==\"%s\", ACTION==\"add|change\", SYMLINK+=\"resume\"\n" \
                ${resume#/dev/};
        } >> /etc/udev/rules.d/99-resume-link.rules

        {
            if [ -x /usr/sbin/resume ]; then
                printf -- 'KERNEL=="%s", ' "${resume#/dev/}"
                printf -- '%s' 'ACTION=="add|change", ENV{ID_FS_TYPE}=="suspend|swsuspend|swsupend",'
                printf -- " RUN+=\"/sbin/initqueue --finished --unique --name 00resume /usr/sbin/resume %s \'%s\'\"\n" \
                     "$a_splash" "$resume";
                printf -- 'SYMLINK=="%s", ' "${resume#/dev/}"
                printf -- '%s' 'ACTION=="add|change", ENV{ID_FS_TYPE}=="suspend|swsuspend|swsupend",'
                printf -- " RUN+=\"/sbin/initqueue --finished --unique --name 00resume /usr/sbin/resume %s \'%s\'\"\n" \
                    "$a_splash" "$resume";
            fi

            printf -- 'KERNEL=="%s", ' "${resume#/dev/}"
            printf -- '%s' 'ACTION=="add|change", ENV{ID_FS_TYPE}=="suspend|swsuspend|swsupend",'
            printf -- '%s\n' ' RUN+="/sbin/initqueue --finished --unique --name 00resume echo %M:%m > /sys/power/resume"'

            printf -- 'SYMLINK=="%s", ' "${resume#/dev/}"
            printf -- '%s' 'ACTION=="add|change", ENV{ID_FS_TYPE}=="suspend|swsuspend|swsupend",'
            printf -- '%s\n' ' RUN+="/sbin/initqueue --finished --unique --name 00resume echo %M:%m  > /sys/power/resume"'
        } >> /etc/udev/rules.d/99-resume.rules

        printf '[ -e "%s" ] && { ln -fs "%s" /dev/resume 2> /dev/null; rm -f -- "$job" "%s/initqueue/timeout/resume.sh"; }\n' \
            "$resume" "$resume" "$hookdir" >> $hookdir/initqueue/settled/resume.sh

        {
            printf -- "%s" 'warn "Cancelling resume operation. Device not found.";'
            printf -- ' cancel_wait_for_dev /dev/resume; rm -f -- "$job" "%s/initqueue/settled/resume.sh";\n' "$hookdir"
        } >> $hookdir/initqueue/timeout/resume.sh

        mv /lib/dracut/resume.sh /lib/dracut/hooks/pre-mount/10-resume.sh
    else
        {
            if [ -x /usr/sbin/resume ]; then
                printf -- '%s' 'SUBSYSTEM=="block", ACTION=="add|change", ENV{ID_FS_TYPE}=="suspend|swsuspend|swsupend",'
                printf -- ' RUN+="/sbin/initqueue --finished --unique --name 00resume /usr/sbin/resume %s $tempnode"\n' "$a_splash"
            fi
            printf -- '%s' 'SUBSYSTEM=="block", ACTION=="add|change", ENV{ID_FS_TYPE}=="suspend|swsuspend|swsupend",'
            printf -- '%s\n' ' RUN+="/sbin/initqueue --finished --unique --name 00resume echo %M:%m > /sys/power/resume"';
        } >> /etc/udev/rules.d/99-resume.rules
    fi
fi
