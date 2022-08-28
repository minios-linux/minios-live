#!/bin/sh

SECURITYFSDIR="/sys/kernel/security"
IMASECDIR="${SECURITYFSDIR}/ima"
IMACONFIG="${NEWROOT}/etc/sysconfig/ima"

load_x509_keys()
{
    KEYRING_ID=$1

    # override the default configuration
    if [ -f "${IMACONFIG}" ]; then
        . ${IMACONFIG}
    fi

    if [ -z "${IMAKEYSDIR}" ]; then
        IMAKEYSDIR="/etc/keys/ima"
    fi

    PUBKEY_LIST=`ls ${NEWROOT}${IMAKEYSDIR}/*`
    for PUBKEY in ${PUBKEY_LIST}; do
        # check for public key's existence
        if [ ! -f "${PUBKEY}" ]; then
            if [ "${RD_DEBUG}" = "yes" ]; then
                info "integrity: IMA x509 cert file not found: ${PUBKEY}"
            fi
            continue
        fi

        X509ID=$(evmctl import ${PUBKEY} ${KEYRING_ID})
        if [ $? -ne 0 ]; then
            info "integrity: IMA x509 cert not loaded on keyring: ${PUBKEY}"
        fi 
    done

    if [ "${RD_DEBUG}" = "yes" ]; then
        keyctl show  ${KEYRING_ID}
    fi
    return 0
}

# check kernel support for IMA
if [ ! -e "${IMASECDIR}" ]; then
    if [ "${RD_DEBUG}" = "yes" ]; then
        info "integrity: IMA kernel support is disabled"
    fi
    return 0
fi

# get the IMA keyring id
line=$(keyctl describe %keyring:.ima)
if [ $? -eq 0 ]; then
    _ima_id=${line%%:*}
else
    _ima_id=`keyctl search @u keyring _ima`
    if [ -z "${_ima_id}" ]; then
        _ima_id=`keyctl newring _ima @u`
    fi
fi

# load the IMA public key(s)
load_x509_keys ${_ima_id}
