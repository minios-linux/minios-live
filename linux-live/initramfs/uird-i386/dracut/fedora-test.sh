#!/bin/bash

set -ex

[[ -d ${0%/*} ]] && cd ${0%/*}

RUN_ID="$1"
TESTS=$2

./configure

NCPU=$(getconf _NPROCESSORS_ONLN)

if ! [[ $TESTS ]]; then
    make -j$NCPU all syncheck rpm logtee
else
    [[ $TESTS == "99" ]] && make_docs=yes || make_docs=no
    make -j$NCPU enable_documentation=$make_docs all logtee

    cd test

    time sudo LOGTEE_TIMEOUT_MS=300000 make \
         enable_documentation=$make_docs \
         KVERSION=$(rpm -qa kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -rn | head -1) \
         DRACUT_NO_XATTR=1 \
         TEST_RUN_ID=$RUN_ID \
         ${TESTS:+TESTS="$TESTS"} \
         -k V=2 \
         check
fi
