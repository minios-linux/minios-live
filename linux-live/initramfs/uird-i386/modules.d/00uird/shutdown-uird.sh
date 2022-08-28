#!/bin/sh
# Author: Alexander Betkher <http://magos-linux.ru>
# Author: Anton Goroshkin <http://magos-linux.ru>
# script must be started only once
# if tmp dir exists, the script is run a second time
[ -d /tmp ] && exit 0

clear 
shell="no" ; ask="no" ; silent="no" ; haltonly="no" ; lowuptime="no" ; log='no'
DEVNULL=''
DEFSQFSOPT="-b 512K -comp lz4"
ACTION=$(ps |grep -m1 shutdown |sed 's:.*/shutdown ::' |cut -f1 -d " ") # reboot or halt
uptime=$(( $(cut -f1 -d "." /proc/uptime) / 60 ))
[ "$uptime" -lt 2 ] && lowuptime=yes

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
brown='\033[0;33m'
blue='\033[0;34m'
light_blue='\033[1;34m'
magenta='\033[1;35m'
cyan='\033[0;36m'
white='\033[0;37m'
purple='\033[0;35m'
default='\033[0m'
black='\033[0;30m'

BALLOON_COLOR="$white"
BALLOON_SPEED='0.01'

get_MUID() {
		# calculate machine UID
		MUID=mac-$(cat /sys/class/net/e*/address 2>/dev/null | head -1 | tr -d :)
		[ "$MUID" = "mac-" ] && MUID=mac-$(cat /sys/class/net/*/address 2>/dev/null | head -1 | tr -d :)
		[ "$MUID" = "mac-"  -o "$MUID" = "mac-000000000000" ] && MUID=vga-$(lspci -mm | grep -i vga | md5sum | cut -c 1-12)
		echo "$MUID"
	}

echolog() {
	echo "$@" 2>/dev/null >> /tmp/uird.shutdown.log
	if 	[ "$silent" == no ] >/dev/null ; then
		local key
		key="$1"
	shift
		echo -e "$key" $@ >/dev/console 2>/dev/console
	fi
}

shell_() {
	echo -e  ${red}"Please, enter \"exit\", to continue shutdown"${default}
	/bin/ash
	echo ''
}

wh_exclude() {
	find $1 -name '.wh.*' |sed -e "s:$1::" -e  's/\/.wh./\//' > /tmp/wh_files
	(cat /tmp/wh_files ;  find $2 |sed "s:$2/:/:" )   |sort |uniq -d > /tmp/wh_exclude
	(cat /tmp/wh_files ; find ${SYSMNT}/changes/ |sed "s:${SYSMNT}/changes/:/:" ) |sort |uniq -d |sed -r 's:^(/.*/)(.*):\1.wh.\2:' >> /tmp/wh_exclude
	rm /tmp/wh_files 
}

banner() {
# $1 BALLOON_COLOR
# $2 BALLOON_SPEED
echo -e $1
t=$2
if [ $COLUMNS ] ; then
	TERMLEN=$COLUMNS
else
	TERMLEN=150
fi
for a in $(seq 50) ; do echo '' ; done
for a in "######" \
"################" \
"########################" \
"##############################" \
"##################################" \
"####################################" \
"######################################" \
"########################################" \
"########################################" \
"######################################" \
"####################################" \
"##################################" \
"############################" \
"########################" \
"####################" \
"################" \
"############" \
"####" \
"######" \
"${LIVEKITNAME}" \
"|" \
"|" \
"\\" \
"    \  " \
"     \ " \
"      |" \
"       \ " \
"        \\" \
"        |" ; do
	sleep $t   
	len=$(expr $(echo "$a" |wc -m) - 1)
  	printf "%*s\n" $[$(("$TERMLEN" + "$len"))/2] "$a"
  
done
for a in $(seq 70) ; do echo '' ; sleep $t; done
echo -e $black
}

rebuild() {
	BALLOON_COLOR="$green"
	echolog "Remounting media for saves..."
	export SYSMNT
	plymouth --quit 2>/dev/null
	/remount 
	[ $? == 0 ] || echo -e "[  ${green}OK${default}  ] Remount complete"
	CFGPWD=$(dirname $CHANGESMNT)
	export CFGPWD # maybe it is not necessary
	if [ -f $CHANGESMNT ] ; then
		. $CHANGESMNT
	else
		echolog "ERROR: $CHANGESMNT no such file!"
		BALLOON_COLOR="$red" 
		BALLOON_SPEED="0.05"
		sleep 10
		return
	fi
	. /shutdown.cfg # this is necessary to hot change the mode
	# number of enumerated sections
	end=$(( $(cat "$CHANGESMNT" |egrep '^[[:space:]]*XZM[[:digit:]]{,2}=' |wc -l) - 1 ))
	# list of not enumerated sections
	notenumerated=$(cat "$CHANGESMNT" |egrep '^[[:space:]]*XZM.*[a-zA-Z]+.*=' |sed -e 's/^[[:space:]]*XZM//' -e 's/=.*$//')
	UNIONFS=aufs
	DEFSRC=${SYSMNT}/changes
	if [ -d ${SYSMNT}/ovl/changes ] ; then
		UNIONFS=overlay
		SRCWORK=${SYSMNT}/ovl/workdir
		DEFSRC=${SYSMNT}/ovl/changes
	fi
	for n in $(seq 0 $end) $notenumerated; do
		SRC=${DEFSRC}
		eval REBUILD=\$REBUILD$n
		eval XZM=\$XZM$n
		[ -z "$XZM" ] && XZM=$(get_MUID).xzm
		eval MODE=\$MODE$n
		eval ADDFILTER="\$ADDFILTER$n"
		eval DROPFILTER="\$DROPFILTER$n"
		eval SQFSOPT="\$SQFSOPT$n"
		if [ "$REBUILD" == "once"  ] ; then
			REBUILD=yes
			sed -i "s/REBUILD$n.*/REBUILD$n='no'/" "$CHANGESMNT" 
		fi	
		[ "$REBUILD" != "yes"  ] && continue
		SAVETOMODULEDIR="$(dirname $CHANGESMNT)"
		[ -w $SAVETOMODULEDIR  ] || continue
		[ "$shell" == "yes" ] && shell_
		if [ "$ask" == "yes" -o "$lowuptime" == "yes" ] ; then
			echolog "Uptime: $uptime min"
			echo -e "${brown}The system is ready to save changes to the $XZM ${default} "
			echo -ne $yellow"(C)ontinue(default), (A)bort: $default"
			read ASK
		case "$ASK" in
			"A" | "a") REBUILD="no" ;;
			*) echolog "Saving changes..." ;;
		esac
		fi
	if [ "$REBUILD" == "yes"  ] ; then
		SAVETOMODULENAME="${SAVETOMODULEDIR}/$XZM"
		[ -z "$SQFSOPT" ] && SQFSOPT="$DEFSQFSOPT"
		#cut aufs artefacts
		mkdir -p /tmp/$n
		echo '#cut aufs artefacts#' > /tmp/$n/excludedfiles
		echo "/.wh..*" >> /tmp/$n/excludedfiles
		#cut garbage
		echo '#cut garbage#'  >> /tmp/$n/excludedfiles
		echo "$SYSMNT" >> /tmp/$n/excludedfiles
		echo "/.cache" >> /tmp/$n/excludedfiles
		echo "/.dbus" >> /tmp/$n/excludedfiles
		echo "/run" >> /tmp/$n/excludedfiles
		echo "/tmp" >> /tmp/$n/excludedfiles
		echo "/dev" >> /tmp/$n/excludedfiles # maybe it is not necessary
		echo "/proc" >> /tmp/$n/excludedfiles # maybe it is not necessary
		echo "/sys" >> /tmp/$n/excludedfiles # maybe it is not necessary
		echo "/mnt" >> /tmp/$n/excludedfiles # maybe it is not necessary
		# if old module exists we have to concatenate it
		if [ -f "$SAVETOMODULENAME" ]; then
		echolog "Old module exists..."
			if [ "$MODE" = "mount+wh" -o "$MODE" = "mount" -o "$MODE" = "overlay" ] ; then
				echolog 'Merging old module and session "changes", it may take a long time'
				UNION=/tmp/UNION
				mkdir -p $UNION ${UNION}-bundle
				mount -o loop "$SAVETOMODULENAME" ${UNION}-bundle			
				if [ "$MODE" = "mount" -a "$UNIONFS" = 'aufs' ] ; then
					mount -t aufs -o br:$SRC=rw:${UNION}-bundle=ro+wh aufs $UNION
					SRC="$UNION"
				elif [ "$MODE" = "mount" -a "$UNIONFS" = 'overlay' ] ; then 
					#mount -t overlay -o redirect_dir=on,metacopy=off,index=on,lowerdir="${UNION}-bundle",upperdir="$SRC",workdir="$SRCWORK" overlay "$UNION"
					mount -t overlay -o redirect_dir=on,metacopy=off,index=off,lowerdir="$SRC":"${UNION}-bundle" overlay "$UNION"
					SRC="$UNION"
				elif [ "$MODE" = "mount+wh" -a "$UNIONFS" = 'aufs' ] ; then
					mount -t aufs -o ro,shwh,br:$SRC=ro+wh:${UNION}-bundle=rr+wh aufs $UNION
					SRC="$UNION"
					echo '#cut filtered files and .wh.* for mount+wh mode#' >> /tmp/$n/excludedfiles
					wh_exclude $SRC ${UNION}-bundle 
					cat /tmp/wh_exclude >> /tmp/$n/excludedfiles
					mv -f /tmp/wh_exclude /tmp/$n/
				elif [ "$MODE" = "mount+wh" -a "$UNIONFS" = 'overlay' ] ; then
					mount -o remount,rw ${SYSMNT} # need if uird.rootfs=zram
					which rsync >/dev/null 2>&1 && \
					rsync -aq --ignore-existing ${UNION}-bundle/* ${SRC}/ || \
					cp -Rn ${UNION}-bundle/* ${SRC}/
				fi
			fi
		fi
		if [ -n "$ADDFILTER" -o -n "$DROPFILTER" ] ;then
			echolog "Please wait. Preparing excludes for module ${SAVETOMODULENAME}....." 
			# do not create list of all files from changes, if it already exists
			[ -f /tmp/allfiles  ] || find $SRC/ | sed -e 's|^'$SRC'||' -e '/^\/$/d' > /tmp/allfiles
			: > /tmp/savelist.black
			: > /tmp/savelist.white
			for item in $ADDFILTER ; do 
				if [ -d "$SRC$item" ] ; then
					echo "^$item" >> /tmp/savelist.white
				else
					echo "$item" >> /tmp/savelist.white 
				fi
			done
			grep -q . /tmp/savelist.white || echo '.' > /tmp/savelist.white
			for item in $DROPFILTER ; do 
				if [ -d "$SRC$item" ] ; then
					echo "^$item" >> /tmp/savelist.black
				else
					echo "$item" >> /tmp/savelist.black 
				fi
			done
			(cat /tmp/allfiles  | grep -f /tmp/savelist.white  \
			| awk -F"/" '{ A = $1 ;{for (i=2; i<=NF; i++) { A = A "/" $i ; print A} } }'  \
			| sort -u | cat - /tmp/allfiles  |sort |uniq -u
			grep -q . /tmp/savelist.black && cat /tmp/allfiles  | grep -f /tmp/savelist.black ) \
			|sort -u >> /tmp/$n/excludedfiles
		fi
		sed -i 's|^/||' /tmp/$n/excludedfiles
		echolog "Please wait. Saving changes to module ${SAVETOMODULENAME}....."
		[ "$shell" = "yes" ] && shell_
		eval mksquashfs $SRC "${SAVETOMODULENAME}.new" -ef /tmp/$n/excludedfiles $SQFSOPT -wildcards $DEVNULL 
		if [ $? == 0 ] ; then
			echolog "[  ${green}OK${default}  ]  $SAVETOMODULENAME  -- complete."
			[ -f "$SAVETOMODULENAME" ] && mv -f "$SAVETOMODULENAME" "${SAVETOMODULENAME}.bak" 
			mv -f "${SAVETOMODULENAME}.new" "$SAVETOMODULENAME" 
			chmod 400 "$SAVETOMODULENAME"
		else
			BALLOON_COLOR="$red" 
			BALLOON_SPEED="0.05"
			echo -e "[  ${red}FALSE!${default}  ]  System changes was not saved to $SAVETOMODULENAME"
			echo "          Changes dir is $SRC, you may try to save it manualy"
			shell_
		fi
			umount $UNION  2> /dev/null 
			rmdir $UNION 2> /dev/null
			umount ${UNION}-bundle 2> /dev/null
			rmdir ${UNION}-bundle 2> /dev/null
	fi
	done
}

mkdir -p /tmp
echolog "UIRD shutdown started!"
date >> /tmp/uird.shutdown.log

[ -f /oldroot/etc/initvars ] && . /oldroot/etc/initvars || BALLOON_COLOR="$red"
[ -f /shutdown.cfg ] && . /shutdown.cfg || BALLOON_COLOR="$red"
if ! [ -d "/oldroot$SYSMNT" ] ; then
	echolog "ERROR:  /oldroot$SYSMNT no such directory"
	BALLOON_COLOR="$red"
	unset CHANGESMNT
	sleep 5
fi 
[ "$silent" = "yes" ] && DEVNULL=">/dev/null 2>&1" 
 
SRC=/oldroot${SYSMNT}/changes
 
mkdir -p ${SYSMNT}
mount -o move /oldroot${SYSMNT}  ${SYSMNT} 

[ "$ACTION" = "reboot" -a "$haltonly" = "yes" ] && unset CHANGESMNT  
if umount /oldroot  ; then
	echolog "[  ${green}OK${default}  ] Umount: ROOTFS"
else
	echolog "[${red}FALSE!${default}] Umount: ROOTFS"	
fi
echolog "$(umount $(mount | egrep -v "tmpfs|zram|proc|sysfs" | awk  '{print $3}' | sort -r) 2>&1) "
n=0
while mount | egrep -v "tmpfs|zram|proc|sysfs" ; do
	echolog "$(umount $(mount | egrep -v "tmpfs|zram|proc|sysfs" | awk  '{print $3}' | sort -r) 2>&1) "
	sleep 0.3 ; n=$(( $n +1 )) 
	[ $n -ge 3 ] && break
done

#save changes to the modules
[ $CHANGESMNT ] && rebuild
sync

# make the log
if [ -d "$CFGPWD" -a "$log" != 'no' ] ;then
	logname=$(echo $CHANGESMNT | sed 's/.cfg$/_log.tar.gz/')
	[ -f $logname ] && mv -f $logname ${logname}.old
	cd /tmp ; tar -czf $logname * ; cd /
fi

for a in $(ls -1 /dev/mapper) ; do
	[ "$a" == 'control' ] && continue
	umount /dev/mapper/$a && cryptsetup luksClose $a &
	sync
done 2>/dev/null

for mntp in $(mount | egrep -v "tmpfs|proc|sysfs" | awk  '{print $3}' | sort -r) ; do
	if umount $mntp ; then 
		echolog "[  ${green}OK${default}  ] Umount: $mntp"
	else
		echo -e "[${red}FALSE!${default}] Umount: $mntp"
		mount -o remount,ro $mntp && echolog "[  ${green}OK${default}  ] Remount RO: $mntp"
	fi
done
[ "$shell" = "yes" ] && shell_
[ "$silent" = "no" ] && banner "$BALLOON_COLOR" "$BALLOON_SPEED"
grep  /dev/sd /proc/mounts && sleep 5
exit 0

