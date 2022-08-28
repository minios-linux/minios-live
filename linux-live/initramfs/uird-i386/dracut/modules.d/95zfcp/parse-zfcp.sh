#!/bin/sh

getargbool 1 rd.zfcp.conf -d -n rd_NO_ZFCPCONF || rm /etc/zfcp.conf

for zfcp_arg in $(getargs rd.zfcp -d 'rd_ZFCP='); do
    echo $zfcp_arg | grep '0\.[0-9a-fA-F]\.[0-9a-fA-F]\{4\},0x[0-9a-fA-F]\{16\},0x[0-9a-fA-F]\{16\}' >/dev/null
    test $? -ne 0 && die "For argument 'rd.zfcp=$zfcp_arg'\nSorry, invalid format."
    (
        IFS=","
        set $zfcp_arg
        echo "$@" >> /etc/zfcp.conf
    )
done

zfcp_cio_free
