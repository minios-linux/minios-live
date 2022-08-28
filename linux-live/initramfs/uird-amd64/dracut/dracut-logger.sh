#!/bin/bash
#
# logging faciality module for dracut both at build- and boot-time
#
# Copyright 2010 Amadeusz Żołnowski <aidecoe@aidecoe.name>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


__DRACUT_LOGGER__=1


## @brief Logging facility module for dracut both at build- and boot-time.
#
# @section intro Introduction
#
# The logger takes a bit from Log4j philosophy. There are defined 6 logging
# levels:
#   - TRACE (6)
#     The TRACE Level designates finer-grained informational events than the
#     DEBUG.
#   - DEBUG (5)
#     The DEBUG Level designates fine-grained informational events that are most
#     useful to debug an application.
#   - INFO (4)
#     The INFO level designates informational messages that highlight the
#     progress of the application at coarse-grained level.
#   - WARN (3)
#     The WARN level designates potentially harmful situations.
#   - ERROR (2)
#     The ERROR level designates error events that might still allow the
#     application to continue running.
#   - FATAL (1)
#     The FATAL level designates very severe error events that will presumably
#     lead the application to abort.
# Descriptions are borrowed from Log4j documentation:
# http://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/Level.html
#
# @section usage Usage
#
# First of all you have to start with dlog_init() function which initializes
# required variables. Don't call any other logging function before that one!
# If you're ready with this, you can use following functions which corresponds
# clearly to levels listed in @ref intro Introduction. Here they are:
#   - dtrace()
#   - ddebug()
#   - dinfo()
#   - dwarn()
#   - derror()
#   - dfatal()
# They take all arguments given as a single message to be logged. See dlog()
# function for details how it works. Note that you shouldn't use dlog() by
# yourself. It's wrapped with above functions.
#
# @see dlog_init() dlog()
#
# @section conf Configuration
#
# Logging is controlled by following global variables:
#   - @var stdloglvl - logging level to standard error (console output)
#   - @var sysloglvl - logging level to syslog (by logger command)
#   - @var fileloglvl - logging level to file
#   - @var kmsgloglvl - logging level to /dev/kmsg (only for boot-time)
#   - @var logfile - log file which is used when @var fileloglvl is higher
#   than 0
# and two global variables: @var maxloglvl and @var syslogfacility which <b>must
# not</b> be overwritten. Both are set by dlog_init(). @var maxloglvl holds
# maximum logging level of those three and indicates that dlog_init() was run.
# @var syslogfacility is set either to 'user' (when building initramfs) or
# 'daemon' (when booting).
#
# Logging level set by the variable means that messages from this logging level
# and above (FATAL is the highest) will be shown. Logging levels may be set
# independently for each destination (stderr, syslog, file, kmsg).
#
# @see dlog_init()


## @brief Initializes dracut Logger.
#
# @retval 1 if something has gone wrong
# @retval 0 on success.
#
# @note This function need to be called before any other from this file.
#
# If any of the variables is not set, this function set it to default:
#   - @var stdloglvl = 4 (info)
#   - @var sysloglvl = 0 (no logging)
#   - @var fileloglvl is set to 4 when @var logfile is set too, otherwise it's
#   - @var kmsgloglvl = 0 (no logging)
#   set to 0
#
# @warning Function sets global variables @var maxloglvl and @syslogfacility.
# See file doc comment for details.
dlog_init() {
    local __oldumask
    local ret=0; local errmsg
    [ -z "$stdloglvl" ] && stdloglvl=4
    [ -z "$sysloglvl" ] && sysloglvl=0
    [ -z "$kmsgloglvl" ] && kmsgloglvl=0
    # Skip initialization if it's already done.
    [ -n "$maxloglvl" ] && return 0

    if [ -z "$fileloglvl" ]; then
        [ -w "$logfile" ] && fileloglvl=4 || fileloglvl=0
    elif (( $fileloglvl > 0 )); then
        if [[ $logfile ]]; then
            __oldumask=$(umask)
            umask 0377
            ! [ -e "$logfile" ] && >"$logfile"
            umask $__oldumask
            if [ -w "$logfile" -a -f "$logfile" ]; then
            # Mark new run in the log file
                echo >>"$logfile"
                if command -v date >/dev/null; then
                    echo "=== $(date) ===" >>"$logfile"
                else
                    echo "===============================================" >>"$logfile"
                fi
                echo >>"$logfile"
            else
            # We cannot log to file, so turn this facility off.
                fileloglvl=0
                ret=1
                errmsg="'$logfile' is not a writable file"
            fi
        fi
    fi

    if (( $UID  != 0 )); then
        kmsgloglvl=0
        sysloglvl=0
    fi

    if (( $sysloglvl > 0 )); then
        if [[ -d /run/systemd/journal ]] \
            && type -P systemd-cat &>/dev/null \
            && systemctl --quiet is-active systemd-journald.socket &>/dev/null \
            && { echo "dracut-$DRACUT_VERSION" | systemd-cat -t 'dracut' &>/dev/null; } ; then
            readonly _systemdcatfile="$DRACUT_TMPDIR/systemd-cat"
            mkfifo "$_systemdcatfile"
            readonly _dlogfd=15
            systemd-cat -t 'dracut' --level-prefix=true <"$_systemdcatfile" &
            exec 15>"$_systemdcatfile"
        elif ! [ -S /dev/log -a -w /dev/log ] || ! command -v logger >/dev/null; then
            # We cannot log to syslog, so turn this facility off.
            kmsgloglvl=$sysloglvl
            sysloglvl=0
            ret=1
            errmsg="No '/dev/log' or 'logger' included for syslog logging"
        fi
    fi

    if (($sysloglvl > 0)) || (($kmsgloglvl > 0 )); then
        if [ -n "$dracutbasedir" ]; then
            readonly syslogfacility=user
        else
            readonly syslogfacility=daemon
        fi
        export syslogfacility
    fi

    local lvl; local maxloglvl_l=0
    for lvl in $stdloglvl $sysloglvl $fileloglvl $kmsgloglvl; do
        (( $lvl > $maxloglvl_l )) && maxloglvl_l=$lvl
    done
    readonly maxloglvl=$maxloglvl_l
    export maxloglvl


    if (($stdloglvl < 6)) && (($kmsgloglvl < 6)) && (($fileloglvl < 6)) && (($sysloglvl < 6)); then
        unset dtrace
        dtrace() { :; };
    fi

    if (($stdloglvl < 5)) && (($kmsgloglvl < 5)) && (($fileloglvl < 5)) && (($sysloglvl < 5)); then
        unset ddebug
        ddebug() { :; };
    fi

    if (($stdloglvl < 4)) && (($kmsgloglvl < 4)) && (($fileloglvl < 4)) && (($sysloglvl < 4)); then
        unset dinfo
        dinfo() { :; };
    fi

    if (($stdloglvl < 3)) && (($kmsgloglvl < 3)) && (($fileloglvl < 3)) && (($sysloglvl < 3)); then
        unset dwarn
        dwarn() { :; };
        unset dwarning
        dwarning() { :; };
    fi

    if (($stdloglvl < 2)) && (($kmsgloglvl < 2)) && (($fileloglvl < 2)) && (($sysloglvl < 2)); then
        unset derror
        derror() { :; };
    fi

    if (($stdloglvl < 1)) && (($kmsgloglvl < 1)) && (($fileloglvl < 1)) && (($sysloglvl < 1)); then
        unset dfatal
        dfatal() { :; };
    fi

    [ -n "$errmsg" ] && derror "$errmsg"

    return $ret
}

## @brief Converts numeric logging level to the first letter of level name.
#
# @param lvl Numeric logging level in range from 1 to 6.
# @retval 1 if @a lvl is out of range.
# @retval 0 if @a lvl is correct.
# @result Echoes first letter of level name.
_lvl2char() {
    case "$1" in
        1) echo F;;
        2) echo E;;
        3) echo W;;
        4) echo I;;
        5) echo D;;
        6) echo T;;
        *) return 1;;
    esac
}

## @brief Converts numeric level to logger priority defined by POSIX.2.
#
# @param lvl Numeric logging level in range from 1 to 6.
# @retval 1 if @a lvl is out of range.
# @retval 0 if @a lvl is correct.
# @result Echoes logger priority.
_lvl2syspri() {
    printf $syslogfacility.
    case "$1" in
        1) echo crit;;
        2) echo error;;
        3) echo warning;;
        4) echo info;;
        5) echo debug;;
        6) echo debug;;
        *) return 1;;
    esac
}

## @brief Converts dracut-logger numeric level to syslog log level
#
# @param lvl Numeric logging level in range from 1 to 6.
# @retval 1 if @a lvl is out of range.
# @retval 0 if @a lvl is correct.
# @result Echoes kernel console numeric log level
#
# Conversion is done as follows:
#
# <tt>
#   none     -> LOG_EMERG (0)
#   none     -> LOG_ALERT (1)
#   FATAL(1) -> LOG_CRIT (2)
#   ERROR(2) -> LOG_ERR (3)
#   WARN(3)  -> LOG_WARNING (4)
#   none     -> LOG_NOTICE (5)
#   INFO(4)  -> LOG_INFO (6)
#   DEBUG(5) -> LOG_DEBUG (7)
#   TRACE(6) /
# </tt>
#
# @see /usr/include/sys/syslog.h
_dlvl2syslvl() {
    local lvl

    case "$1" in
        1) lvl=2;;
        2) lvl=3;;
        3) lvl=4;;
        4) lvl=6;;
        5) lvl=7;;
        6) lvl=7;;
        *) return 1;;
    esac

    [ "$syslogfacility" = user ] && echo $((8+$lvl)) || echo $((24+$lvl))
}

## @brief Prints to stderr and/or writes to file, to syslog and/or /dev/kmsg
# given message with given level (priority).
#
# @param lvl Numeric logging level.
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
#
# @note This function is not supposed to be called manually. Please use
# dtrace(), ddebug(), or others instead which wrap this one.
#
# This is core logging function which logs given message to standard error, file
# and/or syslog (with POSIX shell command <tt>logger</tt>) and/or to /dev/kmsg.
# The format is following:
#
# <tt>X: some message</tt>
#
# where @c X is the first letter of logging level. See module description for
# details on that.
#
# Message to syslog is sent with tag @c dracut. Priorities are mapped as
# following:
#   - @c FATAL to @c crit
#   - @c ERROR to @c error
#   - @c WARN to @c warning
#   - @c INFO to @c info
#   - @c DEBUG and @c TRACE both to @c debug
_do_dlog() {
    local lvl="$1"; shift
    local lvlc=$(_lvl2char "$lvl") || return 0
    local msg="$*"
    local lmsg="$lvlc: $*"

    (( $lvl <= $stdloglvl )) && printf -- 'dracut: %s\n' "$msg" >&2

    if (( $lvl <= $sysloglvl )); then
        if [[ "$_dlogfd" ]]; then
            printf -- "<%s>%s\n" "$(($(_dlvl2syslvl $lvl) & 7))" "$msg" >&$_dlogfd
        else
            logger -t "dracut[$$]" -p $(_lvl2syspri $lvl) -- "$msg"
        fi
    fi

    if (( $lvl <= $fileloglvl )) && [[ -w "$logfile" ]] && [[ -f "$logfile" ]]; then
        echo "$lmsg" >>"$logfile"
    fi

    (( $lvl <= $kmsgloglvl )) && \
        echo "<$(_dlvl2syslvl $lvl)>dracut[$$] $msg" >/dev/kmsg
}

## @brief Internal helper function for _do_dlog()
#
# @param lvl Numeric logging level.
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
#
# @note This function is not supposed to be called manually. Please use
# dtrace(), ddebug(), or others instead which wrap this one.
#
# This function calls _do_dlog() either with parameter msg, or if
# none is given, it will read standard input and will use every line as
# a message.
#
# This enables:
# dwarn "This is a warning"
# echo "This is a warning" | dwarn
dlog() {
    [ -z "$maxloglvl" ] && return 0
    (( $1 <= $maxloglvl )) || return 0

    if (( $# > 1 )); then
        _do_dlog "$@"
    else
        while read line || [ -n "$line" ]; do
            _do_dlog "$1" "$line"
        done
    fi
}

## @brief Logs message at TRACE level (6)
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
dtrace() {
    set +x
    dlog 6 "$@"
    [ -n "$debug" ] && set -x || :
}

## @brief Logs message at DEBUG level (5)
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
ddebug() {
    set +x
    dlog 5 "$@"
    [ -n "$debug" ] && set -x || :
}

## @brief Logs message at INFO level (4)
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
dinfo() {
    set +x
    dlog 4 "$@"
    [ -n "$debug" ] && set -x || :
}

## @brief Logs message at WARN level (3)
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
dwarn() {
    set +x
    dlog 3 "$@"
    [ -n "$debug" ] && set -x || :
}

## @brief It's an alias to dwarn() function.
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
dwarning() {
    set +x
    dwarn "$@"
    [ -n "$debug" ] && set -x || :
}

## @brief Logs message at ERROR level (2)
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
derror() {
    set +x
    dlog 2 "$@"
    [ -n "$debug" ] && set -x || :
}

## @brief Logs message at FATAL level (1)
#
# @param msg Message.
# @retval 0 It's always returned, even if logging failed.
dfatal() {
    set +x
    dlog 1 "$@"
    [ -n "$debug" ] && set -x || :
}
