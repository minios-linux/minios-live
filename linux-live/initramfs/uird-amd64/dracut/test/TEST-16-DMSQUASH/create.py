#!/usr/bin/python -tt
#
# livecd-creator : Creates Live CD based for Fedora.
#
# Copyright 2007, Red Hat  Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

import os
import os.path
import sys
import time
import optparse
import logging
import shutil
from distutils.dir_util import copy_tree

import imgcreate
from imgcreate.fs import makedirs

class myLiveImageCreator(imgcreate.x86LiveImageCreator):
    def __init__(self, ks, name, fslabel=None, releasever=None, tmpdir="/tmp",
                 title="Linux", product="Linux"):

        imgcreate.x86LiveImageCreator.__init__(self, ks, name,
                                               fslabel=fslabel,
                                               releasever=releasever,
                                               tmpdir=tmpdir)

        #self._outdir=os.getenv("TESTDIR", ".")

    def install(self, repo_urls = {}):
        copy_tree(os.environ.get("TESTDIR", ".") + "/root-source", self._instroot)

    def configure(self):
        self._create_bootconfig()

    def _get_kernel_versions(self):
        ret = {}
        version=os.uname()
        version=version[2]
        ret["kernel-" + version] = [version]
        return ret

    def __sanity_check(self):
        pass

class Usage(Exception):
    def __init__(self, msg = None, no_error = False):
        Exception.__init__(self, msg, no_error)

def parse_options(args):
    parser = optparse.OptionParser()

    imgopt = optparse.OptionGroup(parser, "Image options",
                                  "These options define the created image.")
    imgopt.add_option("-c", "--config", type="string", dest="kscfg",
                      help="Path or url to kickstart config file")
    imgopt.add_option("-b", "--base-on", type="string", dest="base_on",
                      help="Add packages to an existing live CD iso9660 image.")
    imgopt.add_option("-f", "--fslabel", type="string", dest="fslabel",
                      help="File system label (default based on config name)")
    # Provided for img-create compatibility
    imgopt.add_option("-n", "--name", type="string", dest="fslabel",
                      help=optparse.SUPPRESS_HELP)
    imgopt.add_option("", "--image-type", type="string", dest="image_type",
                      help=optparse.SUPPRESS_HELP)
    imgopt.add_option("", "--compression-type", type="string", dest="compress_type",
                      help="Compression type recognized by mksquashfs "
                           "(default xz needs a 2.6.38+ kernel, gzip works "
                           "with all kernels, lzo needs a 2.6.36+ kernel, lzma "
                           "needs custom kernel.) Set to 'None' to force read "
                           "from base_on.",
                      default="xz")
    imgopt.add_option("", "--releasever", type="string", dest="releasever",
                      default=None,
                      help="Value to substitute for $releasever in kickstart repo urls")
    parser.add_option_group(imgopt)

    # options related to the config of your system
    sysopt = optparse.OptionGroup(parser, "System directory options",
                                  "These options define directories used on your system for creating the live image")
    sysopt.add_option("-t", "--tmpdir", type="string",
                      dest="tmpdir", default="/var/tmp",
                      help="Temporary directory to use (default: /var/tmp)")
    sysopt.add_option("", "--cache", type="string",
                      dest="cachedir", default=None,
                      help="Cache directory to use (default: private cache")
    parser.add_option_group(sysopt)

    imgcreate.setup_logging(parser)

    # debug options not recommended for "production" images
    # Start a shell in the chroot for post-configuration.
    parser.add_option("-l", "--shell", action="store_true", dest="give_shell",
                      help=optparse.SUPPRESS_HELP)
    # Don't compress the image.
    parser.add_option("-s", "--skip-compression", action="store_true", dest="skip_compression",
                      help=optparse.SUPPRESS_HELP)
    parser.add_option("", "--skip-minimize", action="store_true", dest="skip_minimize",
                      help=optparse.SUPPRESS_HELP)

    (options, args) = parser.parse_args()

    # Pretend to be a image-creator if called with that name
    options.image_type = 'livecd'
    if options.image_type not in ('livecd', 'image'):
        raise Usage("'%s' is a recognized image type" % options.image_type)

    # image-create compatibility: Last argument is kickstart file
    if len(args) == 1:
        options.kscfg = args.pop()
    if len(args):
        raise Usage("Extra arguments given")

    if options.base_on and not os.path.isfile(options.base_on):
        raise Usage("Image file '%s' does not exist" %(options.base_on,))
    if options.image_type == 'livecd':
        if options.fslabel and len(options.fslabel) > imgcreate.FSLABEL_MAXLEN:
            raise Usage("CD labels are limited to 32 characters")
        if options.fslabel and options.fslabel.find(" ") != -1:
            raise Usage("CD labels cannot contain spaces.")

    return options

def main():
    try:
        options = parse_options(sys.argv[1:])
    except Usage as e:
        msg, no_error = e.args
        if no_error:
            out = sys.stdout
            ret = 0
        else:
            out = sys.stderr
            ret = 2
        if msg:
            print >> out, msg
        return ret

    if os.geteuid () != 0:
        print >> sys.stderr, "You must run %s as root" % sys.argv[0]
        return 1

    if options.fslabel:
        fslabel = options.fslabel
        name = fslabel
    else:
        name = "livecd"

        fslabel = "LiveCD"
        logging.info("Using label '%s' and name '%s'" % (fslabel, name))

    ks = imgcreate.read_kickstart(options.kscfg)

    creator = myLiveImageCreator(ks, name,
                                 fslabel=fslabel,
                                 releasever=options.releasever,
                                 tmpdir=os.path.abspath(options.tmpdir))

    creator.compress_type = options.compress_type
    creator.skip_compression = options.skip_compression
    creator.skip_minimize = options.skip_minimize
    if options.cachedir:
        options.cachedir = os.path.abspath(options.cachedir)

    try:
        creator.mount(options.base_on, options.cachedir)
        creator.install()
        creator.configure()
        if options.give_shell:
            print("Launching shell. Exit to continue.")
            print("----------------------------------")
            creator.launch_shell()
        creator.unmount()
        creator.package(os.environ.get("TESTDIR", "."))
    except imgcreate.CreatorError as e:
        logging.error(u"Error creating Live CD : %s" % e)
        return 1
    finally:
        creator.cleanup()

    return 0

if __name__ == "__main__":
    sys.exit(main())
