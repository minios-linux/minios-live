#!/bin/sh

for f in /tmp/dhclient.*.pid; do
    [ -e $f ] || continue
    read PID < $f;
    kill $PID >/dev/null 2>&1
done

sleep 0.1

for f in /tmp/dhclient.*.pid; do
    [ -e $f ] || continue
    read PID < $f;
    kill -9 $PID >/dev/null 2>&1
done
