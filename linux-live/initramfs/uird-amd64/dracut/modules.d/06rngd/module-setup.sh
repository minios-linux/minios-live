#!/bin/bash
# vim: set tabstop=8 shiftwidth=4 softtabstop=4 expandtab smarttab colorcolumn=80:
#
# Copyright (c) 2019 Red Hat, Inc.
# Author: Renaud Métrich <rmetrich@redhat.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

depends() {
    echo systemd
    return 0
}

check() {
    # if there's no rngd binary, no go.
    require_binaries rngd || return 1

    return 0
}

install() {
    inst rngd
    inst_simple "${moddir}/rngd.service" "${systemdsystemunitdir}/rngd.service"

    systemctl -q --root "$initdir" add-wants sysinit.target rngd.service
}
