#!/bin/sh
[ -c /dev/watchdog ] && printf 'V' > /dev/watchdog
