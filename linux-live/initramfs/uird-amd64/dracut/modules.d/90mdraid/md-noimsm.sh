#!/bin/sh

info "rd.md.imsm=0: no MD RAID for imsm/isw raids"
udevproperty rd_NO_MDIMSM=1
