#!/bin/bash

# called by dracut
#
# Parses depmod configuration and calls instmods for out-of-tree kernel
# modules found.  Specifically, kernel modules inside directories that
# come from the following places are included (if these kernel modules
# are present in modules.dep):
#   - "search" configuration option;
#   - "override" configuration option (matching an exact file name constructed
#      by concatenating the provided directory and the kernel module name);
#   - "external" configuration option (if "external" is a part of "search"
#     configuration).
# (See depmod.d(5) for details.)
#
# This module has the following variables available for configuration:
#   - "depmod_modules_dep" - Path to the modules.dep file
#                            ("$srcmods/modules.dep" by default);
#   - "depmod_module_dir" - Directory containing kernel modules ("$srcmods"
#                           by default);
#   - "depmod_configs" - array of depmod configuration paths to parse
#                        (as supplied to depmod -C, ("/run/depmod.d/"
#                        "/etc/depmod.d/" "/lib/depmod.d/") by default).
installkernel()
{
	: "${depmod_modules_dep:=$srcmods/modules.dep}"
	: "${depmod_module_dir:=$srcmods}"

	[[ -f "${depmod_modules_dep}" ]] || return 0

	# Message printers with custom prefix
	local mod_name="kernel-modules-extra"
	prinfo()  { dinfo  "  ${mod_name}: $*"; }
	prdebug() { ddebug "  ${mod_name}: $*"; }

	# Escape a string for usage as a part of extended regular expression.
	# $1 - string to escape
	re_escape() {
		printf "%s" "$1" | sed 's/\([.+?^$\/\\|()\[]\|\]\)/\\\0/'
	}

	local OLDIFS
	local cfg
	local cfgs=()
	local search_list=""
	local overrides=()
	local external_dirs=()
	local e f


	## Gathering and sorting configuration file list

	[ -n "${depmod_configs[@]-}" ] \
		|| depmod_configs=(/run/depmod.d/ /etc/depmod.d/ /lib/depmod.d/)

	for cfg in "${depmod_configs[@]}"; do
		[ -e "$cfg" ] || {
			prdebug "configuration source \"$cfg\" does not exist"
			continue
		}

		# '/' is used as a separator between configuration name and
		# configuration path
		if [ -d "$cfg" ]; then
			for f in "$cfg/"*; do
				[[ -e "$f" && ! -d "$f" ]] || {
					prdebug "configuration source" \
						"\"$cfg\" is ignored" \
						"(directory or doesn't exist)"
					continue
				}
				cfgs+=("$(basename "$f")/$f")
			done
		else
			cfgs+=("$(basename "$cfg")/$cfg")
		fi
	done

	OLDIFS="$IFS"
	IFS=$'\n'
	LANG=C cfgs=($(printf '%s\n' "${cfgs[@]}" \
		| sort -u -k1,1 -t '/' | cut -f 2- -d '/'))
	IFS="$OLDIFS"


	## Parse configurations

	for cfg in "${cfgs[@]}"; do
		prdebug "parsing configuration file \"$cfg\""

		local k v mod kverpat path
		while read -r k v; do
			case "$k" in
			search)
				search_list="$search_list $v"
				prdebug "$cfg: added \"$v\" to the list of" \
					"search directories"
				;;
			override) # module_name kver_pattern dir
				read -r mod kverpat path <<<"$v"

				if [[ ! "$mod" || ! "$kverpat" || ! "$path" ]]
				then
					prinfo "$cfg: ignoring incorrect" \
					       "override option: \"$k $v\""
					continue
				fi

				if [[ '*' = "$kverpat" \
				      || "$kernel" =~ "$kverpat" ]]
				then
					overrides+=("${path}/${mod}")

					prdebug "$cfg: added override" \
						"\"${path}/${mod}\""
				else
					prdebug "$cfg: override \"$v\" is" \
						"ignored since \"$kverpat\"" \
						"doesn't match \"$kernel\""
				fi
				;;
			external) # kverpat dir
				read -r kverpat path <<<"$v"

				if [[ ! "$kverpat" || ! "$path" ]]; then
					prinfo "$cfg: ignoring incorrect" \
					       "external option: \"$k $v\""
					continue
				fi

				if [[ '*' = "$kverpat" \
				      || "$kernel" =~ "$kverpat" ]]
				then
					external_dirs+=("$path")

					prdebug "$cfg: added external" \
						"directory \"$path\""
				else
					prdebug "$cfg: external directory" \
						"\"$path\" is ignored since" \
						"\"$kverpat\" doesn't match " \
						"\"$kernel\""
				fi
				;;
			'#'*|'') # comments and empty strings
				;;
			include|make_map_files) # ignored by depmod
				;;
			*)
				prinfo "$cfg: unknown depmod configuration" \
				       "option \"$k $v\""
				;;
			esac
		done < "$cfg"
	done

	# "updates built-in" is the default search list
	: "${search_list:=updates}"


	## Build a list of regular expressions for grepping modules.dep

	local pathlist=()
	for f in "${overrides[@]}"; do
		pathlist+=("^$(re_escape "$f")")
	done

	for f in $(printf "%s" "$search_list"); do
		# Ignoring builtin modules
		[ "built-in" != "$f" ] || continue

		if [ "external" = "$f" ]; then
			for e in "${external_dirs[@]}"; do
				pathlist+=("$(re_escape "${e%/}")/[^:]+")
			done
		fi

		pathlist+=("$(re_escape "${f%/}")/[^:]+")
	done


	## Filter modules.dep, canonicalise the resulting filenames and supply
	## them to instmods.

	[ 0 -lt "${#pathlist[@]}" ] || return 0

	printf "^%s\.ko(\.gz|\.bz2|\.xz)?:\n" "${pathlist[@]}" \
		| (LANG=C grep -E -o -f - -- "$depmod_modules_dep" || exit 0) \
		| tr -d ':' \
		| (cd "$depmod_module_dir" || exit; xargs -r realpath -se --) \
		| instmods || return 1

	return 0
}
