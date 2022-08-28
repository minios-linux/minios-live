#!/bin/sh
if [ -e /dev/watchdog ]; then
	if [ ! -e /tmp/watchdog_timeout ]; then
		wdctl -s 60 /dev/watchdog >/dev/null 2>&1
		> /tmp/watchdog_timeout
	fi
	info "Triggering watchdog"
	>/dev/watchdog
else
	modprobe ib700wdt
	modprobe i6300esb
fi
