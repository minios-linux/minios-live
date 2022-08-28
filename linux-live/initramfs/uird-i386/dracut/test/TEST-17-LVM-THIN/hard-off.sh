#!/bin/sh
getargbool 0 rd.shell || poweroff -f
getarg failme && poweroff -f
