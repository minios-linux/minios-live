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

_dracut() {
        local field_vals= cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
        local -A OPTS=(
                [STANDALONE]='-f -v -q -l -H -h -M -N
                              --ro-mnt --force --kernel-only --no-kernel --strip --nostrip
                              --hardlink --nohardlink --noprefix --mdadmconf --nomdadmconf
                              --lvmconf --nolvmconf --debug --profile --verbose --quiet
                              --local --hostonly --no-hostonly --fstab --help --bzip2 --lzma
                              --xz --zstd --no-compress --gzip --list-modules --show-modules --keep
                              --printsize --regenerate-all --noimageifnotneeded --early-microcode
                              --no-early-microcode --print-cmdline --reproducible --uefi'

                       [ARG]='-a -m -o -d -I -k -c -L --kver --add --force-add --add-drivers
                              --omit-drivers --modules --omit --drivers --filesystems --install
                              --fwdir --libdirs --fscks --add-fstab --mount --device --nofscks
                              --kmoddir --conf --confdir --tmpdir --stdlog --compress --prefix
                              --kernel-cmdline --sshkey --persistent-policy --install-optional
                              --loginstall --uefi-stub --kernel-image
                              '
        )

        if __contains_word "$prev" ${OPTS[ARG]}; then
                case $prev in
                        --kmoddir|-k|--fwdir|--confdir|--tmpdir)
                                comps=$(compgen -d -- "$cur")
                                compopt -o filenames
                        ;;
                        -c|--conf|--sshkey|--add-fstab|--add-device|-I|--install|--install-optional)
                                comps=$(compgen -f -- "$cur")
                                compopt -o filenames
                        ;;
                        -a|-m|-o|--add|--modules|--omit)
                                comps=$(dracut --list-modules 2>/dev/null)
                        ;;
                        --persistent-policy)
                                comps=$(cd /dev/disk/; echo *)
                        ;;
                        --kver)
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
}

complete -F _dracut dracut
