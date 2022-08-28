#!/bin/sh

# Licensed under the GPLv2
#
# Copyright (C) 2011 Politecnico di Torino, Italy
#                    TORSEC group -- http://security.polito.it
# Roberto Sassu <roberto.sassu@polito.it>

ECRYPTFSCONFIG="${NEWROOT}/etc/sysconfig/ecryptfs"
ECRYPTFSKEYTYPE="encrypted"
ECRYPTFSKEYDESC="1000100010001000"
ECRYPTFSKEYID=""
ECRYPTFSSRCDIR="/secret"
ECRYPTFS_EXTRA_MOUNT_OPTS=""

load_ecryptfs_key()
{
    # override the eCryptfs key path name from the 'ecryptfskey=' parameter in the kernel
    # command line
    ECRYPTFSKEYARG=$(getarg ecryptfskey=)
    [ $? -eq 0 ] && \
        ECRYPTFSKEY=${ECRYPTFSKEYARG}

    # set the default value
    [ -z "${ECRYPTFSKEY}" ] && \
        ECRYPTFSKEY="/etc/keys/ecryptfs-trusted.blob";

    # set the eCryptfs key path name
    ECRYPTFSKEYPATH="${NEWROOT}${ECRYPTFSKEY}"

    # check for eCryptfs encrypted key's existence
    if [ ! -f "${ECRYPTFSKEYPATH}" ]; then
        if [ "${RD_DEBUG}" = "yes" ]; then
            info "eCryptfs: key file not found: ${ECRYPTFSKEYPATH}"
        fi
        return 1
    fi

    # read the eCryptfs encrypted key blob
    KEYBLOB=$(cat ${ECRYPTFSKEYPATH})

    # load the eCryptfs encrypted key blob
    ECRYPTFSKEYID=$(keyctl add ${ECRYPTFSKEYTYPE} ${ECRYPTFSKEYDESC} "load ${KEYBLOB}" @u)
    [ $? -eq 0 ] || {
        info "eCryptfs: failed to load the eCryptfs key: ${ECRYPTFSKEYDESC}";
        return 1;
    }

    return 0
}

unload_ecryptfs_key()
{
    # unlink the eCryptfs encrypted key
    keyctl unlink ${ECRYPTFSKEYID} @u || {
        info "eCryptfs: failed to unlink the eCryptfs key: ${ECRYPTFSKEYDESC}";
        return 1;
    }

    return 0
}

mount_ecryptfs()
{
    # read the configuration from the config file
    [ -f "${ECRYPTFSCONFIG}" ] && \
        . ${ECRYPTFSCONFIG}

    # load the eCryptfs encrypted key
    load_ecryptfs_key || return 1

    # set the default value for ECRYPTFSDSTDIR
    [ -z "${ECRYPTFSDSTDIR}" ] && \
        ECRYPTFSDSTDIR=${ECRYPTFSSRCDIR}

    # set the eCryptfs filesystem mount point
    ECRYPTFSSRCMNT="${NEWROOT}${ECRYPTFSSRCDIR}"
    ECRYPTFSDSTMNT="${NEWROOT}${ECRYPTFSDSTDIR}"

    # build the mount options variable
    ECRYPTFS_MOUNT_OPTS="ecryptfs_sig=${ECRYPTFSKEYDESC}"
    [ ! -z "${ECRYPTFS_EXTRA_MOUNT_OPTS}" ] && \
        ECRYPTFS_MOUNT_OPTS="${ECRYPTFS_MOUNT_OPTS},${ECRYPTFS_EXTRA_MOUNT_OPTS}"

    # mount the eCryptfs filesystem
    info "Mounting the configured eCryptfs filesystem"
    mount -i -t ecryptfs -o${ECRYPTFS_MOUNT_OPTS} ${ECRYPTFSSRCMNT} ${ECRYPTFSDSTMNT} >/dev/null || {
        info "eCryptfs: mount of the eCryptfs filesystem failed";
        return 1;
    }

    # unload the eCryptfs encrypted key
    unload_ecryptfs_key || return 1

    return 0
}

mount_ecryptfs
