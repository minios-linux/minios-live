#!/bin/sh
getarg rd.shell || poweroff -f
getarg failme && poweroff -f
