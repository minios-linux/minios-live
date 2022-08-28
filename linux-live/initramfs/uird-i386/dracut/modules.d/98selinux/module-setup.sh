#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_hook pre-pivot 50 "$moddir/selinux-loadpolicy.sh"
    inst_multiple setenforce
}

