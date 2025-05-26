#!/bin/sh

# Library of shell functions to help write live-config components

pkg_is_installed() {
    local package="$1"
    if [ -z "$package" ]; then
	echo "ERROR: pkg_is_installed() needs a package as parameter" >&2
	exit 1
    fi
    if dpkg-query -f'${db:Status-Status}\n' -W $package 2>/dev/null | grep -q ^installed; then
	return 0
    fi
    return 1
}

pkg_test_version() {
    local package="$1"
    local relation="$2"
    local version="$3"
    if [ -z "$package" ] || [ -z "$relation" ] || [ -z "$version" ]; then
	echo "ERROR: pkg_test_version() takes three arguments: <package>, <relation>, <version>" >&2
	exit 1
    fi
    local instver=$(dpkg-query -f'${Version}\n' -W $package 2>/dev/null)
    if [ -z "$instver" ]; then
	echo "ERROR: can't test version of package $package if it's not installed"
	exit 1
    fi
    if dpkg --compare-versions "$instver" "$relation" "$version" ; then
	return 0
    fi
    return 1
}

component_was_executed() {
    local component="$1"
    if [ -z "$component" ]; then
	echo "ERROR: component_was_executed() needs a component as parameter" >&2
	exit 1
    fi
    if test -e /var/lib/live/config/$component; then
	return 0
    fi
    return 1
}
