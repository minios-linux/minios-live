dracut
====

dracut is an event driven initramfs infrastructure.

[![Build Status](https://travis-ci.org/dracutdevs/dracut.svg?branch=master)](https://travis-ci.org/dracutdevs/dracut)
[![Fedora-30](https://github.com/dracutdevs/dracut/workflows/Fedora-30/badge.svg?branch=master)](https://github.com/dracutdevs/dracut/actions?query=workflow%3AFedora-30)
[![Fedora-31](https://github.com/dracutdevs/dracut/workflows/Fedora-31/badge.svg?branch=master)](https://github.com/dracutdevs/dracut/actions?query=workflow%3AFedora-31)

dracut (the tool) is used to create an initramfs image by copying tools
and files from an installed system and combining it with the
dracut framework, usually found in /usr/lib/dracut/modules.d.

Unlike existing initramfs's, this is an attempt at having as little as
possible hard-coded into the initramfs as possible.  The initramfs has
(basically) one purpose in life -- getting the rootfs mounted so that
we can transition to the real rootfs.  This is all driven off of
device availability.  Therefore, instead of scripts hard-coded to do
various things, we depend on udev to create device nodes for us and
then when we have the rootfs's device node, we mount and carry on.
This helps to keep the time required in the initramfs as little as
possible so that things like a 5 second boot aren't made impossible as
a result of the very existence of an initramfs.  It's likely that
we'll grow some hooks for running arbitrary commands in the flow of
the script, but it's worth trying to resist the urge as much as we can
as hooks are guaranteed to be the path to slow-down.

Most of the initramfs generation functionality in dracut is provided by a bunch
of generator modules that are sourced by the main dracut script to install
specific functionality into the initramfs.  They live in the modules.d
subdirectory, and use functionality provided by dracut-functions to do their
work.

Some general rules for writing modules:
 * Use one of the inst family of functions to actually install files
   on to the initramfs.  They handle mangling the pathnames and (for binaries,
   scripts, and kernel modules) installing dependencies as appropriate so
   you do not have to.
 * Scripts that end up on the initramfs should be POSIX compliant. dracut
   will try to use /bin/dash as /bin/sh for the initramfs if it is available,
   so you should install it on your system -- dash aims for strict POSIX
   compliance to the extent possible.
 * Hooks MUST be POSIX compliant -- they are sourced by the init script,
   and having a bashism break your user's ability to boot really sucks.
 * Generator modules should have a two digit numeric prefix -- they run in
   ascending sort order. Anything in the 90-99 range is stuff that dracut
   relies on, so try not to break those hooks.
 * Hooks must have a .sh extension.
 * Generator modules are described in more detail in README.modules.
 * We have some breakpoints for debugging your hooks.  If you pass 'rdbreak'
   as a kernel parameter, the initramfs will drop to a shell just before
   switching to a new root. You can pass 'rdbreak=hookpoint', and the initramfs
   will break just before hooks in that hookpoint run.

Also, there is an attempt to keep things as distribution-agnostic as
possible.  Every distribution has their own tool here and it's not
something which is really interesting to have separate across them.
So contributions to help decrease the distro-dependencies are welcome.

Currently dracut lives on github.com and kernel.org.

The tarballs can be found here:
	http://www.kernel.org/pub/linux/utils/boot/dracut/
	ftp://ftp.kernel.org/pub/linux/utils/boot/dracut/

Git:
	git://git.kernel.org/pub/scm/boot/dracut/dracut.git
	http://git.kernel.org/pub/scm/boot/dracut/dracut.git
	https://git.kernel.org/pub/scm/boot/dracut/dracut.git

	git@github.com:dracutdevs/dracut.git

Git Web:
	https://github.com/dracutdevs/dracut.git

        http://git.kernel.org/?p=boot/dracut/dracut.git

Project Documentation:
	http://www.kernel.org/pub/linux/utils/boot/dracut/dracut.html

Project Wiki:
	http://dracut.wiki.kernel.org

See the TODO file for things which still need to be done and HACKING for
some instructions on how to get started.  There is also a mailing list
that is being used for the discussion -- initramfs@vger.kernel.org.
It is a typical vger list, send mail to majordomo@vger.kernel.org with body
of 'subscribe initramfs email@host.com'


Licensed under the GPLv2
