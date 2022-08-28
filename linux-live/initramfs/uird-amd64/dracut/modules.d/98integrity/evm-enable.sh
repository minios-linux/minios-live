#!/bin/sh

# Licensed under the GPLv2
#
# Copyright (C) 2011 Politecnico di Torino, Italy
#                    TORSEC group -- http://security.polito.it
# Roberto Sassu <roberto.sassu@polito.it>

EVMSECFILE="${SECURITYFSDIR}/evm"
EVMCONFIG="${NEWROOT}/etc/sysconfig/evm"
EVMKEYDESC="evm-key"
EVMKEYTYPE="encrypted"
EVMKEYID=""

load_evm_key()
{
    # read the configuration from the config file
    [ -f "${EVMCONFIG}" ] && \
        . ${EVMCONFIG}

    # override the EVM key path name from the 'evmkey=' parameter in the kernel
    # command line
    EVMKEYARG=$(getarg evmkey=)
    [ $? -eq 0 ] && \
        EVMKEY=${EVMKEYARG}

    # set the default value
    [ -z "${EVMKEY}" ] && \
        EVMKEY="/etc/keys/evm-trusted.blob";

    # set the EVM key path name
    EVMKEYPATH="${NEWROOT}${EVMKEY}"

    # check for EVM encrypted key's existence
    if [ ! -f "${EVMKEYPATH}" ]; then
        if [ "${RD_DEBUG}" = "yes" ]; then
            info "integrity: EVM encrypted key file not found: ${EVMKEYPATH}"
        fi
        return 1
    fi

    # read the EVM encrypted key blob
    KEYBLOB=$(cat ${EVMKEYPATH})

    # load the EVM encrypted key
    EVMKEYID=$(keyctl add ${EVMKEYTYPE} ${EVMKEYDESC} "load ${KEYBLOB}" @u)
    [ $? -eq 0 ] || {
        info "integrity: failed to load the EVM encrypted key: ${EVMKEYDESC}";
        return 1;
    }
    return 0
}

load_evm_x509()
{
    info "Load EVM IMA X509"

    # override the EVM key path name from the 'evmx509=' parameter in
    # the kernel command line
    EVMX509ARG=$(getarg evmx509=)
    [ $? -eq 0 ] && \
        EVMX509=${EVMX509ARG}

    # set the default value
    [ -z "${EVMX509}" ] && \
        EVMX509="/etc/keys/x509_evm.der";

    # set the EVM public key path name
    EVMX509PATH="${NEWROOT}${EVMX509}"

    # check for EVM public key's existence
    if [ ! -f "${EVMX509PATH}" ]; then
        if [ "${RD_DEBUG}" = "yes" ]; then
            info "integrity: EVM x509 cert file not found: ${EVMX509PATH}"
        fi
        return 1
    fi

    local evm_pubid line
    line=$(keyctl describe %keyring:.evm)
    if [ $? -eq 0 ]; then
        # the kernel already setup a trusted .evm keyring so use that one
        evm_pubid=${line%%:*}
    else
        # look for an existing regular keyring
        evm_pubid=`keyctl search @u keyring _evm`
        if [ -z "${evm_pubid}" ]; then
            # create a new regular _evm keyring
            evm_pubid=`keyctl newring _evm @u`
        fi
    fi

    # load the EVM public key onto the EVM keyring
    EVMX509ID=$(evmctl import ${EVMX509PATH} ${evm_pubid})
    [ $? -eq 0 ] || {
        info "integrity: failed to load the EVM X509 cert ${EVMX509PATH}";
        return 1;
    }

    if [ "${RD_DEBUG}" = "yes" ]; then
        keyctl show @u
    fi

    return 0
}

unload_evm_key()
{
    # unlink the EVM encrypted key
    keyctl unlink ${EVMKEYID} @u || {
        info "integrity: failed to unlink the EVM encrypted key: ${EVMKEYDESC}";
        return 1;
    }

    return 0
}

enable_evm()
{
    # check kernel support for EVM
    if [ ! -e "${EVMSECFILE}" ]; then
        if [ "${RD_DEBUG}" = "yes" ]; then
            info "integrity: EVM kernel support is disabled"
        fi
        return 0
    fi

    local evm_configured

    # try to load the EVM encrypted key
    load_evm_key && evm_configured=1

    # try to load the EVM public key
    load_evm_x509 && evm_configured=1

    # only enable EVM if a key or x509 certificate could be loaded
    if [ -z "$evm_configured" ]; then
        return 1
    fi

    # initialize EVM
    info "Enabling EVM"
    echo 1 > ${EVMSECFILE}

    # unload the EVM encrypted key
    unload_evm_key || return 1

    return 0
}

enable_evm
