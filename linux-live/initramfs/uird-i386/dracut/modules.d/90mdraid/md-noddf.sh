#!/bin/sh

info "rd.md.ddf=0: no MD RAID for SNIA ddf raids"
udevproperty rd_NO_MDDDF=1
