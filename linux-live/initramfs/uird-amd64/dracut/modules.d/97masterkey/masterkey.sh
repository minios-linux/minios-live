#!/bin/sh

# Licensed under the GPLv2
#
# Copyright (C) 2011 Politecnico di Torino, Italy
#                    TORSEC group -- http://security.polito.it
# Roberto Sassu <roberto.sassu@polito.it>

MASTERKEYSCONFIG="${NEWROOT}/etc/sysconfig/masterkey"
MULTIKERNELMODE="NO"
PCRLOCKNUM=11

load_masterkey()
{
    # read the configuration from the config file
    [ -f "${MASTERKEYSCONFIG}" ] && \
        . ${MASTERKEYSCONFIG}

    # override the kernel master key path name from the 'masterkey=' parameter
    # in the kernel command line
    MASTERKEYARG=$(getarg masterkey=)
    [ $? -eq 0 ] && \
        MASTERKEY=${MASTERKEYARG}

    # override the kernel master key type from the 'masterkeytype=' parameter
    # in the kernel command line
    MASTERKEYTYPEARG=$(getarg masterkeytype=)
    [ $? -eq 0 ] && \
        MASTERKEYTYPE=${MASTERKEYTYPEARG}

    # set default values
    [ -z "${MASTERKEYTYPE}" ] && \
        MASTERKEYTYPE="trusted"

    if [ -z "${MASTERKEY}" ]; then
        # append the kernel version to the default masterkey path name
        # if MULTIKERNELMODE is set to YES
        if [ "${MULTIKERNELMODE}" = "YES" ]; then
            MASTERKEY="/etc/keys/kmk-${MASTERKEYTYPE}-$(uname -r).blob"
        else
            MASTERKEY="/etc/keys/kmk-${MASTERKEYTYPE}.blob"
        fi
    fi

    # set the kernel master key path name
    MASTERKEYPATH="${NEWROOT}${MASTERKEY}"

    # check for kernel master key's existence
    if [ ! -f "${MASTERKEYPATH}" ]; then
        if [ "${RD_DEBUG}" = "yes" ]; then
            info "masterkey: kernel master key file not found: ${MASTERKEYPATH}"
        fi
        return 1
    fi

    # read the kernel master key blob
    KEYBLOB=$(cat ${MASTERKEYPATH})

    # add the 'load' prefix if the key type is 'trusted'
    [ "${MASTERKEYTYPE}" = "trusted" ] && \
        KEYBLOB="load ${KEYBLOB} pcrlock=${PCRLOCKNUM}"

    # load the kernel master key
    info "Loading the kernel master key"
    keyctl add "${MASTERKEYTYPE}" "kmk-${MASTERKEYTYPE}" "${KEYBLOB}" @u >/dev/null || {
        info "masterkey: failed to load the kernel master key: kmk-${MASTERKEYTYPE}";
        return 1;
    }

    return 0
}

load_masterkey
