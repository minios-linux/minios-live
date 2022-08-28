#!/bin/bash

for i in $(multipath -l -v1); do
    if ! dmsetup table $i | sed -n '/.*queue_if_no_path.*/q1' ; then
        dmsetup message $i 0 fail_if_no_path
    fi
done
