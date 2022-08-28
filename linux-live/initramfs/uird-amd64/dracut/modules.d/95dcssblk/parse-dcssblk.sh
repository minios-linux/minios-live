#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
dcssblk_arg=$(getarg rd.dcssblk=)
if [ $? = 0 ];then
	info "Loading dcssblk segments=$dcssblk_arg"
	modprobe dcssblk segments=$dcssblk_arg
fi
