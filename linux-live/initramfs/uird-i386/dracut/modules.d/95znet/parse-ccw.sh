#!/bin/sh

for ccw_arg in $(getargs rd.ccw -d 'rd_CCW=') $(getargs rd.znet -d 'rd_ZNET='); do
    echo $ccw_arg >> /etc/ccw.conf
done

znet_cio_free
