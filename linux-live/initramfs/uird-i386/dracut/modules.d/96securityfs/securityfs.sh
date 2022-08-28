#!/bin/sh

SECURITYFSDIR="/sys/kernel/security"
export SECURITYFSDIR

if ! findmnt "${SECURITYFSDIR}" >/dev/null 2>&1; then
   mount -t securityfs -o nosuid,noexec,nodev securityfs ${SECURITYFSDIR} >/dev/null 2>&1
fi
