#
# Copyright 2013 Red Hat, Inc.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
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

__contains_word () {
        local word=$1; shift
        for w in $*; do [[ $w = $word ]] && return 0; done
        return 1
}

_lsinitrd() {
        local field_vals= cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
        local -A OPTS=(
                [STANDALONE]='-s --size -h --help'

                       [ARG]='-f --file -k --kver'
        )

        if __contains_word "$prev" ${OPTS[ARG]}; then
                case $prev in
                        --file|-f)
                                comps=$(compgen -f -- "$cur")
                                compopt -o filenames
                        ;;
                        --kver|-k)
                                comps=$(cd /lib/modules; echo [0-9]*)
                        ;;
                        *)
                                return 0
                        ;;
                esac
                COMPREPLY=( $(compgen -W '$comps' -- "$cur") )
                return 0
        fi

        if [[ $cur = -* ]]; then
                COMPREPLY=( $(compgen -W '${OPTS[*]}' -- "$cur") )
                return 0
        fi

        comps=$(compgen -f -- "$cur")
        compopt -o filenames
        COMPREPLY=( $(compgen -W '$comps' -- "$cur") )
        return 0
}

complete -F _lsinitrd lsinitrd
