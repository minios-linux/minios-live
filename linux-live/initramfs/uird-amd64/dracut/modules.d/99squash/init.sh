#!/bin/sh
/squash/setup-squash.sh

exec /init.stock

echo "Something went wrong when trying to start original init executable!"
exit 1
