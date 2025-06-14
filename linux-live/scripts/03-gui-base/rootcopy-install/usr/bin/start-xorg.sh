#!/bin/sh

USERNAME="live"

# Run startx as the specified user
exec /bin/su --login -c "/usr/bin/startx -- :0 vt7 -ac -nolisten tcp" $USERNAME
