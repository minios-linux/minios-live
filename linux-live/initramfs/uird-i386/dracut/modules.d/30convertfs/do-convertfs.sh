#!/bin/bash

if getargbool 0 rd.convertfs; then
    if getargbool 0 rd.debug; then
        bash -x convertfs "$NEWROOT" 2>&1 | vinfo
    else
        convertfs "$NEWROOT" 2>&1 | vinfo
    fi
fi
