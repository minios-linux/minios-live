#!/bin/bash --norc
#
# mkinitrd compatibility wrapper for SUSE.
#
# Copyright (c) 2013 SUSE Linux Products GmbH. All rights reserved.
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

boot_dir="/boot"
quiet=0
logfile=/var/log/YaST2/mkinitrd.log
dracut_cmd=dracut

error() { echo "$@" >&2; }

usage () {
    [[ $1 = '-n' ]] && cmd=echo || cmd=error

    $cmd "usage: ${0##*/} [options]"
    $cmd ""
    $cmd "	Create initial ramdisk images that contain all kernel modules needed"
    $cmd "	in the early boot process, before the root file system becomes"
    $cmd "	available."
    $cmd "	This usually includes SCSI and/or RAID modules, a file system module"
    $cmd "	for the root file system, or a network interface driver module for dhcp."
    $cmd ""
    $cmd "	options:"
    $cmd "	-f \"feature list\"	Features to be enabled when generating initrd."
    $cmd "				Available features are:"
    $cmd "					iscsi, md, multipath, lvm, lvm2,"
    $cmd "					ifup, fcoe, dcbd"
    $cmd "	-k \"kernel list\"	List of kernel images for which initrd files are"
    $cmd "				created. Defaults to all kernels found in /boot."
    $cmd "	-i \"initrd list\"	List of file names for the initrd; position have"
    $cmd "				match to \"kernel list\". Defaults to all kernels"
    $cmd "				found in /boot."
    $cmd "	-b boot_dir		Boot directory. Defaults to /boot."
    $cmd "	-t tmp_dir		Temporary directory. Defaults to /var/tmp."
    $cmd "	-M map			System.map file to use."
    $cmd "	-A			Create a so called \"monster initrd\" which"
    $cmd "				includes all features and modules possible."
    $cmd "	-B			Do not update bootloader configuration."
    $cmd "	-v			Verbose mode."
    $cmd "	-L			Disable logging."
    $cmd "	-h			This help screen."
    $cmd "	-m \"module list\"	Modules to include in initrd. Defaults to the"
    $cmd "				INITRD_MODULES variable in /etc/sysconfig/kernel"
    $cmd "	-u \"DomU module list\"	Modules to include in initrd. Defaults to the"
    $cmd "				DOMU_INITRD_MODULES variable in"
    $cmd "				/etc/sysconfig/kernel."
    $cmd "	-d root_device		Root device. Defaults to the device from"
    $cmd "				which / is mounted. Overrides the rootdev"
    $cmd "				environment variable if set."
    $cmd "	-j device		Journal device"
    $cmd "	-D interface		Run dhcp on the specified interface."
    $cmd "	-I interface		Configure the specified interface statically."
    $cmd "	-a acpi_dsdt		Obsolete, do not use."
    $cmd "	-s size			Add splash animation and bootscreen to initrd."

    [[ $1 = '-n' ]] && exit 0
    exit 1
}

# Little helper function for reading args from the commandline.
# it automatically handles -a b and -a=b variants, and returns 1 if
# we need to shift $3.
read_arg() {
    # $1 = arg name
    # $2 = arg value
    # $3 = arg parameter
    param="$1"
    local rematch='^[^=]*=(.*)$' result
    if [[ $2 =~ $rematch ]]; then
        read "$param" <<< "${BASH_REMATCH[1]}"
    else
	for ((i=3; $i <= $#; i++)); do
            # Only read next arg if it not an arg itself.
            if [[ ${@:$i:1} = -* ]];then
		break
            fi
            result="$result ${@:$i:1}"
            # There is no way to shift our callers args, so
            # return "no of args" to indicate they should do it instead.
	done
	read "$1" <<< "$result"
        return $(($i - 3))
    fi
}

# Helper functions to calculate ipconfig command line
calc_netmask() {
    local prefix=$1

    [ -z "$prefix" ] && return
    mask=$(( 0xffffffff << (32 - $prefix) ))
    byte1=$(( mask >> 24 ))
    byte2=$(( mask >> 16 ))
    byte3=$(( mask >> 8 ))
    byte4=$(( mask & 0xff ))
    netmask=$(printf "%d.%d.%d.%d" $(( byte1 & 0xff )) $(( byte2 & 0xff )) $(( byte3 & 0xff )) $byte4);

    echo $netmask
}

ipconfig() {
    local interface=$1
    local iplink macaddr broadcast gateway ipaddr prefix netmask

    iplink=$(ip addr show dev $interface | sed -n 's/ *inet \(.*\) brd.*/\1/p')
    macaddr=$(ip addr show dev $interface | sed -n 's/.*ether \(.*\) brd.*/\1/p')
    broadcast=$(ip addr show dev $interface | sed -n 's/.*brd \(.*\) scope.*/\1/p')
    gateway=$(ip route show dev $interface | sed -n 's/default via \([0-9\.]*\).*/\1/p')

    ipaddr=${iplink%%/*}
    prefix=${iplink##*/}
    netmask=$(calc_netmask $prefix)

    echo "${ipaddr}:${serveraddr}:${gateway}:${netmask}:${hostname}:${interface}:none::${macaddr}"
}

is_xen_kernel() {
    local kversion=$1
    local root_dir=$2
    local cfg

    for cfg in ${root_dir}/boot/config-$kversion $root_dir/lib/modules/$kversion/build/.config
    do
        test -r $cfg || continue
        grep -q "^CONFIG_XEN=y\$" $cfg
        return
    done
    test $kversion != "${kversion%-xen*}"
    return
}

kernel_version_from_image() {
    local dir="${1%/*}/"
    [[ "$dir" != "$1" ]] || dir=""
    local kernel_image="$1" kernel_image_gz="${dir}vmlinux-${1#*-}.gz"
    echo kernel_image_gz="'$kernel_image_gz'" >&2

    if get_kernel_version "$kernel_image" 2>/dev/null; then
        return
    fi

    # As a last resort, try vmlinux-$version.gz, which might be around
    get_kernel_version "$kernel_image_gz" 2>/dev/null
}

# Taken over from SUSE mkinitrd
default_kernel_images() {
    local regex kernel_image kernel_version version_version initrd_image
    local qf='%{NAME}-%{VERSION}-%{RELEASE}\n'

    case "${DRACUT_ARCH:-$(uname -m)}" in
        s390|s390x)
            regex='image'
            ;;
        ppc|ppc64)
            regex='vmlinux'
            ;;
        i386|x86_64)
            regex='vmlinuz'
            ;;
        arm*)
            regex='[uz]Image'
            ;;
        aarch64|riscv64)
            regex='Image'
            ;;
        *)  regex='vmlinu.'
            ;;
    esac

    kernel_images=""
    initrd_images=""
    for kernel_image in $(ls $boot_dir \
            | sed -ne "\|^$regex\(-[0-9.]\+-[0-9]\+-[a-z0-9]\+$\)\?|p" \
            | grep -v kdump$ ) ; do

        # Note that we cannot check the RPM database here -- this
        # script is itself called from within the binary kernel
        # packages, and rpm does not allow recursive calls.

        [ -L "$boot_dir/$kernel_image" ] && continue
        [ "${kernel_image%%.gz}" != "$kernel_image" ] && continue

        kernel_version=$(kernel_version_from_image \
                         $boot_dir/$kernel_image 2> /dev/null)
        initrd_image=$(echo $kernel_image | sed -e "s|${regex}|initrd|")
        if [ "$kernel_image" != "$initrd_image" -a \
             -n "$kernel_version" -a \
             -d "/lib/modules/$kernel_version" ]; then
                kernel_images="$kernel_images $boot_dir/$kernel_image"
                initrd_images="$initrd_images $boot_dir/$initrd_image"
        fi
    done
    for kernel_image in $kernel_images;do
	kernels="$kernels ${kernel_image#*-}"
    done
    for initrd_image in $initrd_images;do
	targets="$targets $initrd_image"
    done
}

while (($# > 0)); do
    case ${1%%=*} in
	-f) read_arg feature_list "$@" || shift $?
	    # Could be several features
	    ;;
	-k) # Would be nice to get a list of images here
	    read_arg kernel_images "$@" || shift $?
	    for kernel_image in $kernel_images;do
		[ -L "/boot/$kernel_image" ] && kernel_image="$(readlink "/boot/$kernel_image")"
		kernels="$kernels ${kernel_image#*-}"
	    done
	    ;;
	-i) read_arg initrd_images "$@" || shift $?
	    for initrd_image in $initrd_images;do
		[ -L "/boot/$initrd_image" ] && initrd_image="$(readlink "/boot/$initrd_image")"
		# Check if the initrd_image contains a path.
		# if not, then add the default boot_dir
		dname=`dirname $initrd_image`
		if [ "$dname" == "." ]; then
                    targets="$targets $boot_dir/$initrd_image";
		else
                    targets="$targets $initrd_image";
		fi
	    done
	    ;;
	-b) read_arg boot_dir "$@" || shift $?
	    if [ ! -d $boot_dir ];then
		error "Boot directory $boot_dir does not exist"
		exit 1
	    fi
	    ;;
	-t) read_arg tmp_dir "$@" || shift $?
	    dracut_args="${dracut_args} --tmpdir $tmp_dir"
	    ;;
	-M) read_arg map_file "$@" || shift $?
	    ;;
	-A) dracut_args="${dracut_args} --no-host-only";;
	-B) skip_update_bootloader=1;;
        -v|--verbose) dracut_args="${dracut_args} -v";;
	-L) logfile=;;
        -h|--help) usage -n;;
	-m) read_arg module_list "$@" || shift $? ;;
	-u) read_arg domu_module_list "$@" || shift $?
	    echo "mkinitrd: DomU modules not yet supported" ;;
        -d) read_arg rootfs "$@" || shift $?
            dracut_args="${dracut_args} --filesystems $rootfs" ;;
	-D) read_arg dhcp_if "$@" || shift $?
	    dracut_cmdline="${dracut_cmdline} ip=${dhcp_if}:dhcp"
	    ;;
	-I) read_arg static_if "$@" || shift $?
	    dracut_cmdline="${dracut_cmdline} ip=$(ipconfig $static_if)":
	    ;;
	-a) read_arg acpi_dsdt "$@" || shift $?
	    echo "Obsolete -a param, use acpi_table_dir= and acpi_override= variables in /etc/dracut.conf.d/"
	    exit 1
	    ;;
	-s) read_arg boot_splash "$@" || shift $?
	    echo "mkinitrd: boot splash not yet supported"
	    exit 1
	    ;;
	-V) echo "mkinitrd: vendor scipts are no longer supported"
	    exit 1;;
	--dracut)
	    read_arg dracut_cmd "$@" || shift $? ;;
        --version|-R)
            echo "mkinitrd: dracut compatibility wrapper"
            exit 0;;
	--quiet|-q) quiet=1;;
        *)  if [[ ! $targets ]]; then
            targets=$1
            elif [[ ! $kernels ]]; then
            kernels=$1
            else
            usage
            fi;;
    esac
    shift
done

[[ $targets && $kernels ]] || default_kernel_images
if [[ ! $targets || ! $kernels ]];then
    error "No kernel found in $boot_dir or bad modules dir in /lib/modules"
    exit 1
fi

# We can have several targets/kernels, transform the list to an array
targets=( $targets )
[[ $kernels ]] && kernels=( $kernels )

[[ $logfile ]]        && dracut_args="${dracut_args} --logfile $logfile"
dracut_args="${dracut_args} --force"

[[ $dracut_cmdline ]] && dracut_args="${dracut_args} --kernel-cmdline ${dracut_cmdline}"
[ -z "$(type -p update-bootloader)" ] && skip_update_bootloader=1

# Update defaults from /etc/sysconfig/kernel
if [ -f /etc/sysconfig/kernel ] ; then
    . /etc/sysconfig/kernel
fi
[[ $module_list ]] || module_list="${INITRD_MODULES}"
[[ $domu_module_list ]] || domu_module_list="${DOMU_INITRD_MODULES}"
shopt -s extglob

failed=""

for ((i=0 ; $i<${#targets[@]} ; i++)); do

    if [[ $img_vers ]];then
	target="${targets[$i]}-${kernels[$i]}"
    else
	target="${targets[$i]}"
    fi
    kernel="${kernels[$i]}"

    if is_xen_kernel $kernel $rootfs ; then
	modules_all="${module_list} ${domu_module_list}"
    else
        modules_all="${module_list}"
    fi

    # Remove leading and trailing spaces needs (set above): shopt -s extglob
    modules_all=${modules_all%%+([[:space:]])}
    modules_all=${modules_all##+([[:space:]])}

    echo "Creating initrd: $target"

    # Duplicate code: No way found how to redirect output based on $quiet
    if [[ $quiet == 1 ]];then
        # Duplicate code: --force-drivers must not be called with empty string
        # -> dracut bug workarounded ugly, because of complex whitespace
        # expansion magics
        if [ -n "${modules_all}" ];then
            $dracut_cmd $dracut_args --force-drivers "${modules_all}" "$target" "$kernel" &>/dev/null
            [ $? -ne 0 ] && failed="$failed $target"
        else
            $dracut_cmd $dracut_args "$target" "$kernel" &>/dev/null
            [ $? -ne 0 ] && failed="$failed $target"
        fi
    else
        if [ -n "${modules_all}" ];then
            $dracut_cmd $dracut_args --force-drivers "${modules_all}" "$target" "$kernel"
            [ $? -ne 0 ] && failed="$failed $target"
        else
            $dracut_cmd $dracut_args "$target" "$kernel"
            [ $? -ne 0 ] && failed="$failed $target"
        fi
    fi
done

if [ "$skip_update_bootloader" ] ; then
    echo 2>&1 "Did not refresh the bootloader. You might need to refresh it manually."
else
    update-bootloader --refresh
    [ $? -ne 0 ] && echo "Updating bootloader failed" && exit 1
fi

if [ "$failed" != "" ]; then
    echo "Generating $failed targets failed"
    exit 1
fi

exit 0
