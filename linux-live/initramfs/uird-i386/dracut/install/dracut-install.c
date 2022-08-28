/* dracut-install.c  -- install files and executables

   Copyright (C) 2012 Harald Hoyer
   Copyright (C) 2012 Red Hat, Inc.  All rights reserved.

   This program is free software: you can redistribute it and/or modify
   under the terms of the GNU Lesser General Public License as published by
   the Free Software Foundation; either version 2.1 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with this program; If not, see <http://www.gnu.org/licenses/>.
*/

#define PROGRAM_VERSION_STRING "2"

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#undef _FILE_OFFSET_BITS
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <libgen.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <libkmod.h>
#include <fts.h>
#include <regex.h>
#include <sys/utsname.h>

#include "log.h"
#include "hashmap.h"
#include "util.h"
#include "strv.h"

static bool arg_hmac = false;
static bool arg_createdir = false;
static int arg_loglevel = -1;
static bool arg_optional = false;
static bool arg_silent = false;
static bool arg_all = false;
static bool arg_module = false;
static bool arg_modalias = false;
static bool arg_resolvelazy = false;
static bool arg_resolvedeps = false;
static bool arg_hostonly = false;
static bool no_xattr = false;
static char *destrootdir = NULL;
static char *sysrootdir = NULL;
static size_t sysrootdirlen = 0;
static char *kerneldir = NULL;
static size_t kerneldirlen = 0;
static char **firmwaredirs = NULL;
static char **pathdirs;
static char *ldd = NULL;
static char *logdir = NULL;
static char *logfile = NULL;
FILE *logfile_f = NULL;
static Hashmap *items = NULL;
static Hashmap *items_failed = NULL;
static Hashmap *modules_loaded = NULL;
static regex_t mod_filter_path;
static regex_t mod_filter_nopath;
static regex_t mod_filter_symbol;
static regex_t mod_filter_nosymbol;
static regex_t mod_filter_noname;
static bool arg_mod_filter_path = false;
static bool arg_mod_filter_nopath = false;
static bool arg_mod_filter_symbol = false;
static bool arg_mod_filter_nosymbol = false;
static bool arg_mod_filter_noname = false;

static int dracut_install(const char *src, const char *dst, bool isdir, bool resolvedeps, bool hashdst);


static inline void kmod_module_unrefp(struct kmod_module **p) {
        if (*p)
                kmod_module_unref(*p);
}
#define _cleanup_kmod_module_unref_ _cleanup_(kmod_module_unrefp)

static inline void kmod_module_unref_listp(struct kmod_list **p) {
        if (*p)
                kmod_module_unref_list(*p);
}
#define _cleanup_kmod_module_unref_list_ _cleanup_(kmod_module_unref_listp)

static inline void kmod_module_info_free_listp(struct kmod_list **p) {
        if (*p)
                kmod_module_info_free_list(*p);
}
#define _cleanup_kmod_module_info_free_list_ _cleanup_(kmod_module_info_free_listp)

static inline void kmod_unrefp(struct kmod_ctx **p) {
        kmod_unref(*p);
}
#define _cleanup_kmod_unref_ _cleanup_(kmod_unrefp)

static inline void kmod_module_dependency_symbols_free_listp(struct kmod_list **p) {
        if (*p)
                kmod_module_dependency_symbols_free_list(*p);
}
#define _cleanup_kmod_module_dependency_symbols_free_list_ _cleanup_(kmod_module_dependency_symbols_free_listp)

static inline void fts_closep(FTS **p) {
        if (*p)
                fts_close(*p);
}
#define _cleanup_fts_close_ _cleanup_(fts_closep)



static size_t dir_len(char const *file)
{
        size_t length;

        if (!file)
                return 0;

        /* Strip the basename and any redundant slashes before it.  */
        for (length = strlen(file) - 1; 0 < length; length--)
                if (file[length] == '/' && file[length - 1] != '/')
                        break;
        return length;
}

static char *convert_abs_rel(const char *from, const char *target)
{
        /* we use the 4*MAXPATHLEN, which should not overrun */
        char relative_from[MAXPATHLEN * 4];
        _cleanup_free_ char *realtarget = NULL;
        _cleanup_free_ char *target_dir_p = NULL, *realpath_p = NULL;
        const char *realfrom = from;
        size_t level = 0, fromlevel = 0, targetlevel = 0;
        int l;
        size_t i, rl, dirlen;
        int ret;

        target_dir_p = strdup(target);
        if (!target_dir_p)
                return strdup(from);

        dirlen = dir_len(target_dir_p);
        target_dir_p[dirlen] = '\0';
        realpath_p = realpath(target_dir_p, NULL);

        if (realpath_p == NULL) {
                log_warning("convert_abs_rel(): target '%s' directory has no realpath.", target);
                return strdup(from);
        }

        /* dir_len() skips double /'s e.g. //lib64, so we can't skip just one
         * character - need to skip all leading /'s */
        rl = strlen(target);
        for (i = dirlen + 1; i < rl; ++i)
                if (target_dir_p[i] != '/')
                        break;
        ret = asprintf(&realtarget, "%s/%s", realpath_p, &target_dir_p[i]);
        if (ret < 0) {
                log_error("Out of memory!");
                exit(EXIT_FAILURE);
        }

        /* now calculate the relative path from <from> to <target> and
           store it in <relative_from>
         */
        relative_from[0] = 0;
        rl = 0;

        /* count the pathname elements of realtarget */
        for (targetlevel = 0, i = 0; realtarget[i]; i++)
                if (realtarget[i] == '/')
                        targetlevel++;

        /* count the pathname elements of realfrom */
        for (fromlevel = 0, i = 0; realfrom[i]; i++)
                if (realfrom[i] == '/')
                        fromlevel++;

        /* count the pathname elements, which are common for both paths */
        for (level = 0, i = 0; realtarget[i] && (realtarget[i] == realfrom[i]); i++)
                if (realtarget[i] == '/')
                        level++;

        /* add "../" to the relative_from path, until the common pathname is
           reached */
        for (i = level; i < targetlevel; i++) {
                if (i != level)
                        relative_from[rl++] = '/';
                relative_from[rl++] = '.';
                relative_from[rl++] = '.';
        }

        /* set l to the next uncommon pathname element in realfrom */
        for (l = 1, i = 1; i < level; i++)
                for (l++; realfrom[l] && realfrom[l] != '/'; l++) ;
        /* skip next '/' */
        l++;

        /* append the uncommon rest of realfrom to the relative_from path */
        for (i = level; i <= fromlevel; i++) {
                if (rl)
                        relative_from[rl++] = '/';
                while (realfrom[l] && realfrom[l] != '/')
                        relative_from[rl++] = realfrom[l++];
                l++;
        }

        relative_from[rl] = 0;
        return strdup(relative_from);
}

static int ln_r(const char *src, const char *dst)
{
        int ret;
        _cleanup_free_ const char *points_to = convert_abs_rel(src, dst);

        log_info("ln -s '%s' '%s'", points_to, dst);
        ret = symlink(points_to, dst);

        if (ret != 0) {
                log_error("ERROR: ln -s '%s' '%s': %m", points_to, dst);
                return 1;
        }

        return 0;
}

/* Perform the O(1) btrfs clone operation, if possible.
   Upon success, return 0.  Otherwise, return -1 and set errno.  */
static inline int clone_file(int dest_fd, int src_fd)
{
#undef BTRFS_IOCTL_MAGIC
#define BTRFS_IOCTL_MAGIC 0x94
#undef BTRFS_IOC_CLONE
#define BTRFS_IOC_CLONE _IOW (BTRFS_IOCTL_MAGIC, 9, int)
        return ioctl(dest_fd, BTRFS_IOC_CLONE, src_fd);
}

static bool use_clone = true;

static int cp(const char *src, const char *dst)
{
        int pid;
        int ret = 0;

        if (use_clone) {
                struct stat sb;
                _cleanup_close_ int dest_desc = -1, source_desc = -1;

                if (lstat(src, &sb) != 0)
                        goto normal_copy;

                if (S_ISLNK(sb.st_mode))
                        goto normal_copy;

                source_desc = open(src, O_RDONLY | O_CLOEXEC);
                if (source_desc < 0)
                        goto normal_copy;

                dest_desc =
                    open(dst, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC,
                         (sb.st_mode) & (S_ISUID | S_ISGID | S_ISVTX | S_IRWXU | S_IRWXG | S_IRWXO));

                if (dest_desc < 0) {
                        goto normal_copy;
                }

                ret = clone_file(dest_desc, source_desc);

                if (ret == 0) {
                        struct timeval tv[2];
                        if (fchown(dest_desc, sb.st_uid, sb.st_gid) != 0)
                                if(fchown(dest_desc, (uid_t) - 1, sb.st_gid) != 0) {
                                        if (geteuid() == 0)
                                                log_error("Failed to chown %s: %m", dst);
                                        else
                                                log_info("Failed to chown %s: %m", dst);
                                }

                        tv[0].tv_sec = sb.st_atime;
                        tv[0].tv_usec = 0;
                        tv[1].tv_sec = sb.st_mtime;
                        tv[1].tv_usec = 0;
                        futimes(dest_desc, tv);
                        return ret;
                }
                close(dest_desc);
                dest_desc = -1;
                /* clone did not work, remove the file */
                unlink(dst);
                /* do not try clone again */
                use_clone = false;
        }

 normal_copy:
        pid = fork();
        if (pid == 0) {
                if (geteuid() == 0 && no_xattr == false)
                        execlp("cp", "cp", "--reflink=auto", "--sparse=auto", "--preserve=mode,xattr,timestamps", "-fL", src, dst,
                               NULL);
                else
                        execlp("cp", "cp", "--reflink=auto", "--sparse=auto", "--preserve=mode,timestamps", "-fL", src, dst,
                               NULL);
                _exit(EXIT_FAILURE);
        }

        while (waitpid(pid, &ret, 0) < 0) {
                if (errno != EINTR) {
                        ret = -1;
                        if (geteuid() == 0 && no_xattr == false)
                                log_error("Failed: cp --reflink=auto --sparse=auto --preserve=mode,xattr,timestamps -fL %s %s", src,
                                          dst);
                        else
                                log_error("Failed: cp --reflink=auto --sparse=auto --preserve=mode,timestamps -fL %s %s", src,
                                          dst);
                        break;
                }
        }
        log_debug("cp ret = %d", ret);
        return ret;
}

static int library_install(const char *src, const char *lib)
{
        _cleanup_free_ char *p = NULL;
        _cleanup_free_ char *pdir = NULL, *ppdir = NULL, *clib = NULL;
        char *q;
        int r, ret = 0;

        p = strdup(lib);

        r = dracut_install(p, p, false, false, true);
        if (r != 0)
                log_error("ERROR: failed to install '%s' for '%s'", p, src);
        else
                log_debug("Lib install: '%s'", p);
        ret += r;

        /* also install lib.so for lib.so.* files */
        q = strstr(p, ".so.");
        if (q) {
                q[3] = '\0';

                /* ignore errors for base lib symlink */
                if (dracut_install(p, p, false, false, true) == 0)
                        log_debug("Lib install: '%s'", p);
        }

        /* Also try to install the same library from one directory above.
           This fixes the case, where only the HWCAP lib would be installed
           # ldconfig -p|grep -F libc.so
           libc.so.6 (libc6,64bit, hwcap: 0x0000001000000000, OS ABI: Linux 2.6.32) => /lib64/power6/libc.so.6
           libc.so.6 (libc6,64bit, hwcap: 0x0000000000000200, OS ABI: Linux 2.6.32) => /lib64/power6x/libc.so.6
           libc.so.6 (libc6,64bit, OS ABI: Linux 2.6.32) => /lib64/libc.so.6
         */

        free(p);
        p = strdup(lib);

        pdir = dirname(p);
        if (!pdir)
                return ret;

        pdir = strdup(pdir);
        ppdir = dirname(pdir);
        if (!ppdir)
                return ret;

        ppdir = strdup(ppdir);

        strcpy(p, lib);

        clib = strjoin(ppdir, "/", basename(p), NULL);
        if (dracut_install(clib, clib, false, false, true) == 0)
                log_debug("Lib install: '%s'", clib);
        /* also install lib.so for lib.so.* files */
        q = strstr(clib, ".so.");
        if (q) {
                q[3] = '\0';

                /* ignore errors for base lib symlink */
                if (dracut_install(clib, clib, false, false, true) == 0)
                        log_debug("Lib install: '%s'", p);
        }

        return ret;
}

static char *get_real_file(const char *src, bool fullyresolve)
{
        char linktarget[PATH_MAX + 1];
        ssize_t linksz;
        _cleanup_free_ char *fullsrcpath;
        char *abspath = NULL;
        struct stat sb;

        if (sysrootdirlen) {
                if (strncmp(src, sysrootdir, sysrootdirlen) == 0)
                        fullsrcpath = strdup(src);
                else if (asprintf(&fullsrcpath, "%s/%s", (sysrootdirlen ? sysrootdir : ""), (src[0] == '/' ? src+1 : src)) < 0)
				        _exit(EXIT_FAILURE);
        } else
                fullsrcpath = strdup(src);

        log_debug("get_real_file('%s')", fullsrcpath);

        if (lstat(fullsrcpath, &sb) < 0)
            return NULL;

        switch (sb.st_mode & S_IFMT) {
        case S_IFDIR:
        case S_IFREG:
            return strdup(fullsrcpath);
        case S_IFLNK:
            break;
        default:
            return NULL;
        }

        linksz = readlink(fullsrcpath, linktarget, sizeof(linktarget));
        if (linksz < 0)
                return NULL;
        linktarget[linksz] = '\0';

        log_debug("get_real_file: readlink('%s') returns '%s'", fullsrcpath, linktarget);

        if (linktarget[0] == '/') {
                if (asprintf(&abspath, "%s%s", (sysrootdirlen ? sysrootdir : ""), linktarget) < 0)
                        return NULL;
        } else {
                _cleanup_free_ char *fullsrcdir = strdup(fullsrcpath);

                if (!fullsrcdir) {
                        log_error("Out of memory!");
                        return NULL;
                }

                fullsrcdir[dir_len(fullsrcdir)] = '\0';

                if (asprintf(&abspath, "%s/%s", fullsrcdir, linktarget) < 0)
                        return NULL;
        }

        if (fullyresolve) {
                struct stat st;
                if (lstat(abspath, &st) < 0) {
                        if (errno != ENOENT)
                                return NULL;
                }
                if (S_ISLNK(st.st_mode))
                        return get_real_file(abspath, fullyresolve);
        }

        log_debug("get_real_file('%s') => '%s'", src, abspath);
        return abspath;
}

static int resolve_deps(const char *src)
{
        int ret = 0;

        _cleanup_free_ char *buf = NULL;
        size_t linesize = LINE_MAX;
        _cleanup_pclose_ FILE *fptr = NULL;
        _cleanup_free_ char *cmd = NULL;
        _cleanup_free_ char *fullsrcpath = NULL;

        fullsrcpath = get_real_file(src, true);
        log_debug("resolve_deps('%s') -> get_real_file('%s', true) = '%s'", src, src, fullsrcpath);
        if (!fullsrcpath)
                return 0;

        buf = malloc(LINE_MAX);
        if (buf == NULL)
                return -errno;

        if (strstr(src, ".so") == 0) {
                _cleanup_close_ int fd = -1;
                fd = open(fullsrcpath, O_RDONLY | O_CLOEXEC);
                if (fd < 0)
                        return -errno;

                ret = read(fd, buf, LINE_MAX);
                if (ret == -1)
                        return -errno;

                buf[LINE_MAX - 1] = '\0';
                if (buf[0] == '#' && buf[1] == '!') {
                        /* we have a shebang */
                        char *p, *q;
                        for (p = &buf[2]; *p && isspace(*p); p++) ;
                        for (q = p; *q && (!isspace(*q)); q++) ;
                        *q = '\0';
                        log_debug("Script install: '%s'", p);
                        ret = dracut_install(p, p, false, true, false);
                        if (ret != 0)
                                log_error("ERROR: failed to install '%s'", p);
                        return ret;
                }
        }

        /* run ldd */
        ret = asprintf(&cmd, "%s %s 2>&1", ldd, fullsrcpath);
        if (ret < 0) {
                log_error("Out of memory!");
                exit(EXIT_FAILURE);
        }

        log_debug("%s", cmd);

        ret = 0;

        fptr = popen(cmd, "r");

        while (!feof(fptr)) {
                char *p;

                if (getline(&buf, &linesize, fptr) <= 0)
                        continue;

                log_debug("ldd: '%s'", buf);

                if (strstr(buf, "you do not have execution permission")) {
                        log_error("%s", buf);
                        ret += 1;
                        break;
                }

                /* errors from cross-compiler-ldd */
                if (strstr(buf, "unable to find sysroot") || strstr(buf, "command not found")) {
                        log_error("%s", buf);
                        ret += 1;
                        break;
                }

                /* musl ldd */
                if (strstr(buf, "Not a valid dynamic program"))
                        break;

                /* glibc */
                if (strstr(buf, "cannot execute binary file"))
                        break;

                if (strstr(buf, "not a dynamic executable"))
                        break;

                if (strstr(buf, "loader cannot load itself"))
                        break;

                if (strstr(buf, "not regular file"))
                        break;

                if (strstr(buf, "cannot read header"))
                        break;

                if (strstr(buf, destrootdir))
                        break;

                p = strchr(buf, '/');
                if (p) {
                        char *q;

                        for (q = p; *q && *q != ' ' && *q != '\n'; q++) ;
                        *q = '\0';

                        ret += library_install(src, p);

                }
        }

        return ret;
}

/* Install ".<filename>.hmac" file for FIPS self-checks */
static int hmac_install(const char *src, const char *dst, const char *hmacpath)
{
        _cleanup_free_ char *srcpath = strdup(src);
        _cleanup_free_ char *dstpath = strdup(dst);
        _cleanup_free_ char *srchmacname = NULL;
        _cleanup_free_ char *dsthmacname = NULL;
        int ret;

        if (!(srcpath && dstpath))
                return -ENOMEM;

        size_t dlen = dir_len(src);

        if (endswith(src, ".hmac"))
                return 0;

        if (!hmacpath) {
                hmac_install(src, dst, "/lib/fipscheck");
                hmac_install(src, dst, "/lib64/fipscheck");
                hmac_install(src, dst, "/lib/hmaccalc");
                hmac_install(src, dst, "/lib64/hmaccalc");
        }

        srcpath[dlen] = '\0';
        dstpath[dir_len(dst)] = '\0';
        if (hmacpath) {
                ret = asprintf(&srchmacname, "%s/%s.hmac", hmacpath, &src[dlen + 1]);
                if (ret < 0) {
                        log_error("Out of memory!");
                        exit(EXIT_FAILURE);
                }

                ret = asprintf(&dsthmacname, "%s/%s.hmac", hmacpath, &src[dlen + 1]);
                if (ret < 0) {
                        log_error("Out of memory!");
                        exit(EXIT_FAILURE);
                }
        } else {
                ret = asprintf(&srchmacname, "%s/.%s.hmac", srcpath, &src[dlen + 1]);
                if (ret < 0) {
                        log_error("Out of memory!");
                        exit(EXIT_FAILURE);
                }

                ret = asprintf(&dsthmacname, "%s/.%s.hmac", dstpath, &src[dlen + 1]);
                if (ret < 0) {
                        log_error("Out of memory!");
                        exit(EXIT_FAILURE);
                }
        }
        log_debug("hmac cp '%s' '%s')", srchmacname, dsthmacname);
        dracut_install(srchmacname, dsthmacname, false, false, true);
        return 0;
}

void mark_hostonly(const char *path)
{
        _cleanup_free_ char *fulldstpath = NULL;
        _cleanup_fclose_ FILE *f = NULL;
        int ret;

        ret = asprintf(&fulldstpath, "%s/lib/dracut/hostonly-files", destrootdir);
        if (ret < 0) {
                log_error("Out of memory!");
                exit(EXIT_FAILURE);
        }

        f = fopen(fulldstpath, "a");

        if (f == NULL) {
                log_error("Could not open '%s' for writing.", fulldstpath);
                return;
        }

        fprintf(f, "%s\n", path);
}

void dracut_log_cp(const char *path)
{
        int ret;
        ret = fprintf(logfile_f, "%s\n", path);
        if (ret < 0)
                log_error("Could not append '%s' to logfile '%s': %m", path, logfile);
}

static bool check_hashmap(Hashmap *hm, const char *item)
{
        char *existing;
        existing = hashmap_get(hm, item);
        if (existing) {
                if (strcmp(existing, item) == 0) {
                        return true;
                }
        }
        return false;
}

static int dracut_mkdir(const char *src) {
        _cleanup_free_ char *parent = NULL;
        char *path;
        struct stat sb;

        parent = strdup(src);
        if (!parent)
                return 1;

        path = parent[0] == '/' ? parent+1 : parent;
        while (path) {
                path = strstr(path, "/");
                if (path)
                        *path = '\0';

                if (stat(parent, &sb) == 0) {
                        if (!S_ISDIR(sb.st_mode)) {
                                log_error("%s exists but is not a directory!", parent);
                                return 1;
                        }
                } else if (errno != ENOENT) {
                        log_error("ERROR: stat '%s': %s", parent, strerror(errno));
                        return 1;
                } else {
                        if (mkdir(parent, 0755) < 0) {
                                log_error("ERROR: mkdir '%s': %s", parent, strerror(errno));
                                return 1;
                        }
                }

                if (path) {
                        *path = '/';
                        path++;
                }
        }

        return 0;
}

static int dracut_install(const char *orig_src, const char *orig_dst, bool isdir, bool resolvedeps, bool hashdst)
{
        struct stat sb, db;
        _cleanup_free_ char *fullsrcpath = NULL;
        _cleanup_free_ char *fulldstpath = NULL;
        _cleanup_free_ char *fulldstdir = NULL;
        int ret;
        bool src_islink = false;
        bool src_isdir = false;
        mode_t src_mode = 0;
        bool dst_exists = true;
        char *i = NULL;
        _cleanup_free_ char *src;
        _cleanup_free_ char *dst;

        if (sysrootdirlen) {
                if (strncmp(orig_src, sysrootdir, sysrootdirlen) == 0) {
                        src = strdup(orig_src + sysrootdirlen);
                        fullsrcpath = strdup(orig_src);
                } else {
                        src = strdup(orig_src);
                        if (asprintf(&fullsrcpath, "%s%s", sysrootdir, src) < 0)
                                _exit(EXIT_FAILURE);
                }
                if (strncmp(orig_dst, sysrootdir, sysrootdirlen) == 0)
                        dst = strdup(orig_dst + sysrootdirlen);
                else
                        dst = strdup(orig_dst);
        } else {
                src = strdup(orig_src);
                fullsrcpath = strdup(src);
                dst = strdup(orig_dst);
        }

        log_debug("dracut_install('%s', '%s', %d, %d, %d)", src, dst, isdir, resolvedeps, hashdst);

        if (check_hashmap(items_failed, src)) {
                log_debug("hash hit items_failed for '%s'", src);
                return 1;
        }

        if (hashdst && check_hashmap(items, dst)) {
                log_debug("hash hit items for '%s'", dst);
                return 0;
        }

        if (lstat(fullsrcpath, &sb) < 0) {
                if (!isdir) {
                        i = strdup(src);
                        hashmap_put(items_failed, i, i);
                        /* src does not exist */
                        return 1;
                }
        } else {
                src_islink = S_ISLNK(sb.st_mode);
                src_isdir = S_ISDIR(sb.st_mode);
                src_mode = sb.st_mode;
        }

        ret = asprintf(&fulldstpath, "%s/%s", destrootdir, (dst[0]=='/' ? (dst+1) : dst));
        if (ret < 0) {
                log_error("Out of memory!");
                exit(EXIT_FAILURE);
        }

        ret = stat(fulldstpath, &sb);

        if (ret != 0) {
                dst_exists = false;
                if (errno != ENOENT) {
                        log_error("ERROR: stat '%s': %m", fulldstpath);
                        return 1;
                }
        }

        if (ret == 0) {
                if (resolvedeps && S_ISREG(sb.st_mode) && (sb.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH))) {
                        log_debug("'%s' already exists, but checking for any deps", fulldstpath);
                        ret = resolve_deps(fullsrcpath + sysrootdirlen);
                } else
                        log_debug("'%s' already exists", fulldstpath);

                /* dst does already exist */
                return ret;
        }

        /* check destination directory */
        fulldstdir = strdup(fulldstpath);
        if (!fulldstdir) {
                log_error("Out of memory!");
                return 1;
        }
        fulldstdir[dir_len(fulldstdir)] = '\0';

        ret = stat(fulldstdir, &db);

        if (ret < 0) {
                _cleanup_free_ char *dname = NULL;

                if (errno != ENOENT) {
                        log_error("ERROR: stat '%s': %m", fulldstdir);
                        return 1;
                }
                /* create destination directory */
                log_debug("dest dir '%s' does not exist", fulldstdir);
                dname = strdup(dst);
                if (!dname)
                        return 1;

                dname[dir_len(dname)] = '\0';
                ret = dracut_install(dname, dname, true, false, true);

                if (ret != 0) {
                        log_error("ERROR: failed to create directory '%s'", fulldstdir);
                        return 1;
                }
        }

        if (src_isdir) {
                if (dst_exists) {
                        if (S_ISDIR(sb.st_mode)) {
                                log_debug("dest dir '%s' already exists", fulldstpath);
                                return 0;
                        }
                        log_error("dest dir '%s' already exists but is not a directory", fulldstpath);
                        return 1;
                }

                log_info("mkdir '%s'", fulldstpath);
                ret = dracut_mkdir(fulldstpath);
                if (ret == 0) {
                        i = strdup(dst);
                        if (!i)
                                return -ENOMEM;

                        hashmap_put(items, i, i);
                }
                return ret;
        }

        /* ready to install src */

        if (src_islink) {
                _cleanup_free_ char *abspath = NULL;

                abspath = get_real_file(src, false);

                if (abspath == NULL)
                        return 1;

                if (dracut_install(abspath, abspath, false, resolvedeps, hashdst)) {
                        log_debug("'%s' install error", abspath);
                        return 1;
                }

                if (lstat(abspath, &sb) != 0) {
                        log_debug("lstat '%s': %m", abspath);
                        return 1;
                }

                if (lstat(fulldstpath, &sb) != 0) {
                        _cleanup_free_ char *absdestpath = NULL;

                        ret = asprintf(&absdestpath, "%s/%s", destrootdir, (abspath[0]=='/' ? (abspath+1) : abspath) + sysrootdirlen);
                        if (ret < 0) {
                                log_error("Out of memory!");
                                exit(EXIT_FAILURE);
                        }

                        ln_r(absdestpath, fulldstpath);
                }

                if (arg_hmac) {
                        /* copy .hmac files also */
                        hmac_install(src, dst, NULL);
                }

                return 0;
        }

        if (src_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) {
                if (resolvedeps)
                        ret += resolve_deps(fullsrcpath + sysrootdirlen);
                if (arg_hmac) {
                        /* copy .hmac files also */
                        hmac_install(src, dst, NULL);
                }
        }

        log_debug("dracut_install ret = %d", ret);

        if (arg_hostonly && !arg_module)
                mark_hostonly(dst);

        if (isdir) {
                log_info("mkdir '%s'", fulldstpath);
                ret += dracut_mkdir(fulldstpath);
        } else {
                log_info("cp '%s' '%s'", fullsrcpath, fulldstpath);
                ret += cp(fullsrcpath, fulldstpath);
        }

        if (ret == 0) {
                i = strdup(dst);
                if (!i)
                        return -ENOMEM;

                hashmap_put(items, i, i);

                if (logfile_f)
                        dracut_log_cp(src);
        }

        log_debug("dracut_install ret = %d", ret);

        return ret;
}

static void item_free(char *i)
{
        assert(i);
        free(i);
}

static void usage(int status)
{
              /*                                                                                */
        printf("Usage: %s -D DESTROOTDIR [-r SYSROOTDIR] [OPTION]... -a SOURCE...\n"
               "or: %s -D DESTROOTDIR [-r SYSROOTDIR] [OPTION]... SOURCE DEST\n"
               "or: %s -D DESTROOTDIR [-r SYSROOTDIR] [OPTION]... -m KERNELMODULE [KERNELMODULE …]\n"
               "\n"
               "Install SOURCE (from rootfs or SYSROOTDIR) to DEST in DESTROOTDIR with all needed dependencies.\n"
               "\n"
               "  KERNELMODULE can have the format:\n"
               "     <absolute path> with a leading /\n"
               "     =<kernel subdir>[/<kernel subdir>…] like '=drivers/hid'\n"
               "     <module name>\n"
               "\n"
               "  -D --destrootdir  Install all files to DESTROOTDIR as the root\n"
               "  -r --sysrootdir   Install all files from SYSROOTDIR\n"
               "  -a --all          Install all SOURCE arguments to DESTROOTDIR\n"
               "  -o --optional     If SOURCE does not exist, do not fail\n"
               "  -d --dir          SOURCE is a directory\n"
               "  -l --ldd          Also install shebang executables and libraries\n"
               "  -L --logdir <DIR> Log files, which were installed from the host to <DIR>\n"
               "  -R --resolvelazy  Only install shebang executables and libraries\n"
               "                     for all SOURCE files\n"
               "  -H --hostonly     Mark all SOURCE files as hostonly\n\n"
               "  -f --fips         Also install all '.SOURCE.hmac' files\n"
               "\n"
               "  --module,-m       Install kernel modules, instead of files\n"
               "  --kerneldir       Specify the kernel module directory\n"
               "  --firmwaredirs    Specify the firmware directory search path with : separation\n"
               "  --silent          Don't display error messages for kernel module install\n"
               "  --modalias        Only generate module list from /sys/devices modalias list\n"
               "  -o --optional     If kernel module does not exist, do not fail\n"
               "  -p --mod-filter-path      Filter kernel modules by path regexp\n"
               "  -P --mod-filter-nopath    Exclude kernel modules by path regexp\n"
               "  -s --mod-filter-symbol    Filter kernel modules by symbol regexp\n"
               "  -S --mod-filter-nosymbol  Exclude kernel modules by symbol regexp\n"
               "  -N --mod-filter-noname    Exclude kernel modules by name regexp\n"
               "\n"
               "  -v --verbose      Show more output\n"
               "     --debug        Show debug output\n"
               "     --version      Show package version\n"
               "  -h --help         Show this help\n"
               "\n",
               program_invocation_short_name, program_invocation_short_name,
               program_invocation_short_name);
        exit(status);
}

static int parse_argv(int argc, char *argv[])
{
        int c;

        enum {
                ARG_VERSION = 0x100,
                ARG_SILENT,
                ARG_MODALIAS,
                ARG_KERNELDIR,
                ARG_FIRMWAREDIRS,
                ARG_DEBUG
        };

        static struct option const options[] = {
                {"help", no_argument, NULL, 'h'},
                {"version", no_argument, NULL, ARG_VERSION},
                {"dir", no_argument, NULL, 'd'},
                {"debug", no_argument, NULL, ARG_DEBUG},
                {"verbose", no_argument, NULL, 'v'},
                {"ldd", no_argument, NULL, 'l'},
                {"resolvelazy", no_argument, NULL, 'R'},
                {"optional", no_argument, NULL, 'o'},
                {"hostonly", no_argument, NULL, 'H'},
                {"all", no_argument, NULL, 'a'},
                {"module", no_argument, NULL, 'm'},
                {"fips", no_argument, NULL, 'f'},
                {"destrootdir", required_argument, NULL, 'D'},
                {"sysrootdir", required_argument, NULL, 'r'},
                {"logdir", required_argument, NULL, 'L'},
                {"mod-filter-path", required_argument, NULL, 'p'},
                {"mod-filter-nopath", required_argument, NULL, 'P'},
                {"mod-filter-symbol", required_argument, NULL, 's'},
                {"mod-filter-nosymbol", required_argument, NULL, 'S'},
                {"mod-filter-noname", required_argument, NULL, 'N'},
                {"modalias", no_argument, NULL, ARG_MODALIAS},
                {"silent", no_argument, NULL, ARG_SILENT},
                {"kerneldir", required_argument, NULL, ARG_KERNELDIR},
                {"firmwaredirs", required_argument, NULL, ARG_FIRMWAREDIRS},
                {NULL, 0, NULL, 0}
        };

        while ((c = getopt_long(argc, argv, "madfhlL:oD:Hr:Rp:P:s:S:N:v", options, NULL)) != -1) {
                switch (c) {
                case ARG_VERSION:
                        puts(PROGRAM_VERSION_STRING);
                        return 0;
                case 'd':
                        arg_createdir = true;
                        break;
                case ARG_DEBUG:
                        arg_loglevel = LOG_DEBUG;
                        break;
                case ARG_SILENT:
                        arg_silent = true;
                        break;
                case ARG_MODALIAS:
                        arg_modalias = true;
                        return 1;
                        break;
                case 'v':
                        arg_loglevel = LOG_INFO;
                        break;
                case 'o':
                        arg_optional = true;
                        break;
                case 'l':
                        arg_resolvedeps = true;
                        break;
                case 'R':
                        arg_resolvelazy = true;
                        break;
                case 'a':
                        arg_all = true;
                        break;
                case 'm':
                        arg_module = true;
                        break;
                case 'D':
                        destrootdir = strdup(optarg);
                        break;
                case 'r':
                        sysrootdir = strdup(optarg);
                        sysrootdirlen = strlen(sysrootdir);
                        break;
                case 'p':
                        if (regcomp(&mod_filter_path, optarg, REG_NOSUB|REG_EXTENDED) != 0) {
                                log_error("Module path filter %s is not a regular expression", optarg);
                                exit(EXIT_FAILURE);
                        }
                        arg_mod_filter_path = true;
                        break;
                case 'P':
                        if (regcomp(&mod_filter_nopath, optarg, REG_NOSUB|REG_EXTENDED) != 0) {
                                log_error("Module path filter %s is not a regular expression", optarg);
                                exit(EXIT_FAILURE);
                        }
                        arg_mod_filter_nopath = true;
                        break;
                case 's':
                        if (regcomp(&mod_filter_symbol, optarg, REG_NOSUB|REG_EXTENDED) != 0) {
                                log_error("Module symbol filter %s is not a regular expression", optarg);
                                exit(EXIT_FAILURE);
                        }
                        arg_mod_filter_symbol = true;
                        break;
                case 'S':
                        if (regcomp(&mod_filter_nosymbol, optarg, REG_NOSUB|REG_EXTENDED) != 0) {
                                log_error("Module symbol filter %s is not a regular expression", optarg);
                                exit(EXIT_FAILURE);
                        }
                        arg_mod_filter_nosymbol = true;
                        break;
                case 'N':
                        if (regcomp(&mod_filter_noname, optarg, REG_NOSUB|REG_EXTENDED) != 0) {
                                log_error("Module symbol filter %s is not a regular expression", optarg);
                                exit(EXIT_FAILURE);
                        }
                        arg_mod_filter_noname = true;
                        break;
                case 'L':
                        logdir = strdup(optarg);
                        break;
                case ARG_KERNELDIR:
                        kerneldir = strdup(optarg);
                        break;
                case ARG_FIRMWAREDIRS:
                        firmwaredirs = strv_split(optarg, ":");
                        break;
                case 'f':
                        arg_hmac = true;
                        break;
                case 'H':
                        arg_hostonly = true;
                        break;
                case 'h':
                        usage(EXIT_SUCCESS);
                        break;
                default:
                        usage(EXIT_FAILURE);
                }
        }

        if (!kerneldir) {
                struct utsname buf;
                uname(&buf);
                kerneldir = strdup(buf.version);
        }

        if (arg_modalias) {
                return 1;
        }

        if (arg_module) {
                if (!firmwaredirs) {
                        char *path = NULL;

                        path = getenv("DRACUT_FIRMWARE_PATH");

                        if (path == NULL) {
                                log_error("Environment variable DRACUT_FIRMWARE_PATH is not set");
                                exit(EXIT_FAILURE);
                        }

                        log_debug("DRACUT_FIRMWARE_PATH=%s", path);

                        firmwaredirs = strv_split(path, ":");
                }
        }

        if (!optind || optind == argc) {
                log_error("No SOURCE argument given");
                usage(EXIT_FAILURE);
        }

        return 1;
}

static int resolve_lazy(int argc, char **argv)
{
        int i;
        size_t destrootdirlen = strlen(destrootdir);
        int ret = 0;
        char *item;
        for (i = 0; i < argc; i++) {
                const char *src = argv[i];
                char *p = argv[i];
                char *existing;

                log_debug("resolve_deps('%s')", src);

                if (strstr(src, destrootdir)) {
                        p = &argv[i][destrootdirlen];
                }

                existing = hashmap_get(items, p);
                if (existing) {
                        if (strcmp(existing, p) == 0)
                                continue;
                }

                item = strdup(p);
                hashmap_put(items, item, item);

                ret += resolve_deps(src);
        }
        return ret;
}

static char **find_binary(const char *src)
{
        char **ret = NULL;
        char **q;
        char *fullsrcpath;
        char *newsrc = NULL;

        STRV_FOREACH(q, pathdirs) {
                struct stat sb;
                int r;

                r = asprintf(&newsrc, "%s/%s", *q, src);
                if (r < 0) {
                        log_error("Out of memory!");
                        exit(EXIT_FAILURE);
                }

                fullsrcpath = get_real_file(newsrc, false);

                if (!fullsrcpath) {
                        log_debug("get_real_file(%s) not found", newsrc);
                        free(newsrc);
                        newsrc = NULL;
                        continue;
                }

                if (lstat(fullsrcpath, &sb) != 0) {
                        log_debug("stat(%s) != 0", fullsrcpath);
                        free(newsrc);
                        newsrc = NULL;
                        free(fullsrcpath);
                        fullsrcpath = NULL;
                        continue;
                }

                strv_push(&ret, newsrc);

                free(fullsrcpath);
                fullsrcpath = NULL;
        };

        if (ret) {
                STRV_FOREACH(q, ret) {
                        log_debug("find_binary(%s) == %s", src, *q);
                }
        }

        return ret;
}

static int install_one(const char *src, const char *dst)
{
        int r = EXIT_SUCCESS;
        int ret = 0;

        if (strchr(src, '/') == NULL) {
                char **p = find_binary(src);
                if (p) {
                        char **q = NULL;
                        STRV_FOREACH(q, p) {
                                char *newsrc = *q;
                                log_debug("dracut_install '%s' '%s'", newsrc, dst);
                                ret = dracut_install(newsrc, dst, arg_createdir, arg_resolvedeps, true);
                                if (ret == 0) {
                                        log_debug("dracut_install '%s' '%s' OK", newsrc, dst);
                                }
                        }
                        strv_free(p);
                } else {
                        ret = -1;
                }
        } else {
                ret = dracut_install(src, dst, arg_createdir, arg_resolvedeps, true);
        }

        if ((ret != 0) && (!arg_optional)) {
                log_error("ERROR: installing '%s' to '%s'", src, dst);
                r = EXIT_FAILURE;
        }

        return r;
}

static int install_all(int argc, char **argv)
{
        int r = EXIT_SUCCESS;
        int i;
        for (i = 0; i < argc; i++) {
                int ret = 0;
                log_debug("Handle '%s'", argv[i]);

                if (strchr(argv[i], '/') == NULL) {
                        char **p = find_binary(argv[i]);
                        if (p) {
                                char **q = NULL;
                                STRV_FOREACH(q, p) {
                                        char *newsrc = *q;
                                        log_debug("dracut_install '%s'", newsrc);
                                        ret = dracut_install(newsrc, newsrc, arg_createdir, arg_resolvedeps, true);
                                        if (ret == 0) {
                                                log_debug("dracut_install '%s' OK", newsrc);
                                        }
                                }
                                strv_free(p);
                        } else {
                                ret = -1;
                        }

                } else {
                        _cleanup_free_ char *dest = strdup(argv[i]);
                        ret = dracut_install(argv[i], dest, arg_createdir, arg_resolvedeps, true);
                }

                if ((ret != 0) && (!arg_optional)) {
                        log_error("ERROR: installing '%s'", argv[i]);
                        r = EXIT_FAILURE;
                }
        }
        return r;
}

static int install_firmware(struct kmod_module *mod)
{
        struct kmod_list *l;
        _cleanup_kmod_module_info_free_list_ struct kmod_list *list = NULL;
        int ret;

        char **q;

        ret = kmod_module_get_info(mod, &list);
        if (ret < 0) {
                log_error("could not get modinfo from '%s': %s\n",
                          kmod_module_get_name(mod), strerror(-ret));
                return ret;
        }
        kmod_list_foreach(l, list) {
                const char *key = kmod_module_info_get_key(l);
                const char *value = NULL;

                if (!streq("firmware", key))
                        continue;

                value = kmod_module_info_get_value(l);
                log_debug("Firmware %s", value);
                ret = -1;
                STRV_FOREACH(q, firmwaredirs) {
                        _cleanup_free_ char *fwpath = NULL;
                        _cleanup_free_ char *fwpath_xz = NULL;
                        const char *fw;
                        struct stat sb;
                        int r;

                        r = asprintf(&fwpath, "%s/%s", *q, value);
                        if (r < 0) {
                                log_error("Out of memory!");
                                exit(EXIT_FAILURE);
                        }

                        fw = fwpath;
                        if (stat(fwpath, &sb) != 0) {
                                r = asprintf(&fwpath_xz, "%s.xz", fwpath);
                                if (r < 0) {
                                        log_error("Out of memory!");
                                        exit(EXIT_FAILURE);
                                }
                                if (stat(fwpath_xz, &sb) != 0) {
                                        log_debug("stat(%s) != 0", fwpath);
                                        continue;
                                }
                                fw = fwpath_xz;
                        }

                        ret = dracut_install(fw, fw, false, false, true);
                        if (ret == 0)
                                log_debug("dracut_install '%s' OK", fwpath);
                }

                if (ret != 0) {
                        log_info("Possible missing firmware %s for kernel module %s", value, kmod_module_get_name(mod));
                }
        }
        return 0;
}

static bool check_module_symbols(struct kmod_module *mod)
{
        struct kmod_list *itr;
        _cleanup_kmod_module_dependency_symbols_free_list_ struct kmod_list *deplist = NULL;

        if (!arg_mod_filter_symbol && !arg_mod_filter_nosymbol)
                return true;

        if (kmod_module_get_dependency_symbols(mod, &deplist) < 0) {
                log_debug("kmod_module_get_dependency_symbols failed");
                if (arg_mod_filter_symbol)
                        return false;
                return true;
        }

        if (arg_mod_filter_nosymbol) {
                kmod_list_foreach(itr, deplist) {
                        const char *symbol = kmod_module_symbol_get_symbol(itr);
                        // log_debug("Checking symbol %s", symbol);
                        if (regexec(&mod_filter_nosymbol, symbol, 0, NULL, 0) == 0) {
                                log_debug("Module %s: symbol %s matched exclusion filter", kmod_module_get_name(mod), symbol);
                                return false;
                        }
                }
        }

        if (arg_mod_filter_symbol) {
                kmod_list_foreach(itr, deplist) {
                        const char *symbol = kmod_module_dependency_symbol_get_symbol(itr);
                        // log_debug("Checking symbol %s", symbol);
                        if (regexec(&mod_filter_symbol, symbol, 0, NULL, 0) == 0) {
                                log_debug("Module %s: symbol %s matched inclusion filter", kmod_module_get_name(mod), symbol);
                                return true;
                        }
                }
                return false;
        }

        return true;
}

static bool check_module_path(const char *path)
{
        if (arg_mod_filter_nopath && (regexec(&mod_filter_nopath, path, 0, NULL, 0) == 0)) {
                log_debug("Path %s matched exclusion filter", path);
                return false;
        }

        if (arg_mod_filter_path && (regexec(&mod_filter_path, path, 0, NULL, 0) != 0)) {
                log_debug("Path %s matched inclusion filter", path);
                return false;
        }
        return true;
}

static int install_dependent_modules(struct kmod_list *modlist)
{
        struct kmod_list *itr;
        const char *path = NULL;
        const char *name = NULL;
        int ret = 0;

        kmod_list_foreach(itr, modlist) {
		_cleanup_kmod_module_unref_ struct kmod_module *mod = NULL;
                mod = kmod_module_get_module(itr);
                path = kmod_module_get_path(mod);

                if (path == NULL)
                        continue;

		if (check_hashmap(items_failed, path))
			return -1;

		if (check_hashmap(items, path)) {
			continue;
		}

                name = kmod_module_get_name(mod);

                if (arg_mod_filter_noname && (regexec(&mod_filter_noname, name, 0, NULL, 0) == 0)) {
                        continue;
                }

                ret = dracut_install(path, &path[kerneldirlen], false, false, true);
                if (ret == 0) {
			_cleanup_kmod_module_unref_list_ struct kmod_list *modlist = NULL;
			_cleanup_kmod_module_unref_list_ struct kmod_list *modpre = NULL;
			_cleanup_kmod_module_unref_list_ struct kmod_list *modpost = NULL;
                        log_debug("dracut_install '%s' '%s' OK", path, &path[kerneldirlen]);
                        install_firmware(mod);
			modlist = kmod_module_get_dependencies(mod);
			ret = install_dependent_modules(modlist);
			if (ret == 0) {
				ret = kmod_module_get_softdeps(mod, &modpre, &modpost);
				if (ret == 0)
					ret = install_dependent_modules(modpre);
			}
                } else {
                        log_error("dracut_install '%s' '%s' ERROR", path, &path[kerneldirlen]);
                }
        }

        return ret;
}

static int install_module(struct kmod_module *mod)
{
        int ret = 0;
        _cleanup_kmod_module_unref_list_ struct kmod_list *modlist = NULL;
        _cleanup_kmod_module_unref_list_ struct kmod_list *modpre = NULL;
        _cleanup_kmod_module_unref_list_ struct kmod_list *modpost = NULL;
        const char *path = NULL;
        const char *name = NULL;

        name = kmod_module_get_name(mod);
        if (arg_mod_filter_noname && (regexec(&mod_filter_noname, name, 0, NULL, 0) == 0)) {
                log_debug("dracut_install '%s' is excluded", name);
                return 0;
        }

        if (arg_hostonly && !check_hashmap(modules_loaded, name)) {
                log_debug("dracut_install '%s' not hostonly", name);
                return 0;
        }

        path = kmod_module_get_path(mod);
        if (!path)
                return -ENOENT;

        if (check_hashmap(items_failed, path))
                return -1;

        if (check_hashmap(items, path))
                return 0;

        if (!check_module_path(path) || !check_module_symbols(mod)) {
                log_debug("No symbol or path match for '%s'", path);
                return 1;
        }

        log_debug("dracut_install '%s' '%s'", path, &path[kerneldirlen]);

        ret = dracut_install(path, &path[kerneldirlen], false, false, true);
        if (ret == 0) {
                log_debug("dracut_install '%s' OK", kmod_module_get_name(mod));
        } else if (!arg_optional) {
                if (!arg_silent)
                        log_error("dracut_install '%s' ERROR", kmod_module_get_name(mod));
                return ret;
        }
        install_firmware(mod);

        modlist = kmod_module_get_dependencies(mod);
        ret = install_dependent_modules(modlist);

        if (ret == 0) {
                ret = kmod_module_get_softdeps(mod, &modpre, &modpost);
                if (ret == 0)
                        ret = install_dependent_modules(modpre);
        }

        return ret;
}

static int modalias_list(struct kmod_ctx *ctx)
{
        int err;
        struct kmod_list *loaded_list = NULL;
        struct kmod_list *itr, *l;
        _cleanup_fts_close_ FTS *fts = NULL;

        {
                char *paths[] = { "/sys/devices", NULL };
                fts = fts_open(paths, FTS_NOCHDIR|FTS_NOSTAT, NULL);
        }
        for (FTSENT *ftsent = fts_read(fts); ftsent != NULL; ftsent = fts_read(fts)) {
                _cleanup_fclose_ FILE *f = NULL;
                _cleanup_kmod_module_unref_list_ struct kmod_list *list = NULL;
                struct kmod_list *l;

                int err;

                char alias[2048];
                size_t len;

                if (strncmp("modalias", ftsent->fts_name, 8) != 0)
                        continue;
                if (!(f = fopen(ftsent->fts_accpath, "r")))
                        continue;

                if(!fgets(alias, sizeof(alias), f))
                        continue;

                len = strlen(alias);

                if (len == 0)
                        continue;

                if (alias[len-1] == '\n')
                        alias[len-1] = 0;

                err = kmod_module_new_from_lookup(ctx, alias, &list);
                if (err < 0)
                        continue;

                kmod_list_foreach(l, list) {
                        struct kmod_module *mod = kmod_module_get_module(l);
                        char *name = strdup(kmod_module_get_name(mod));
                        kmod_module_unref(mod);
                        hashmap_put(modules_loaded, name, name);
                }
        }

        err = kmod_module_new_from_loaded(ctx, &loaded_list);
        if (err < 0) {
                errno = err;
                log_error("Could not get list of loaded modules: %m. Switching to non-hostonly mode.");
                arg_hostonly = false;
        } else {
                kmod_list_foreach(itr, loaded_list) {
                        _cleanup_kmod_module_unref_list_ struct kmod_list *modlist = NULL;

                        struct kmod_module *mod = kmod_module_get_module(itr);
                        char *name = strdup(kmod_module_get_name(mod));
                        hashmap_put(modules_loaded, name, name);
                        kmod_module_unref(mod);

                        /* also put the modules from the new kernel in the hashmap,
                         * which resolve the name as an alias, in case a kernel module is
                         * renamed.
                         */
                        err = kmod_module_new_from_lookup(ctx, name, &modlist);
                        if (err < 0)
                                continue;
                        if (!modlist)
                                continue;
                        kmod_list_foreach(l, modlist) {
                                mod = kmod_module_get_module(l);
                                char *name = strdup(kmod_module_get_name(mod));
                                hashmap_put(modules_loaded, name, name);
                                kmod_module_unref(mod);
                        }
                }
                kmod_module_unref_list(loaded_list);
        }
        return 0;
}

static int install_modules(int argc, char **argv)
{
        _cleanup_kmod_unref_ struct kmod_ctx *ctx = NULL;
        struct kmod_list *itr;

        struct kmod_module *mod = NULL, *mod_o = NULL;

        const char *abskpath = NULL;
        char *p;
        int i;
        int modinst = 0;

        ctx = kmod_new(kerneldir, NULL);
        abskpath = kmod_get_dirname(ctx);

        p = strstr(abskpath, "/lib/modules/");
        if (p != NULL)
                kerneldirlen = p - abskpath;

        if (arg_hostonly) {
                char *modalias_file;
                modalias_file = getenv("DRACUT_KERNEL_MODALIASES");

                if (modalias_file == NULL) {
                        modalias_list(ctx);
                } else {
                        _cleanup_fclose_ FILE *f = NULL;
                        if ((f = fopen(modalias_file, "r"))) {
                                char name[2048];

                                while (!feof(f)) {
                                        size_t len;
                                        char *dupname = NULL;

                                        if(!(fgets(name, sizeof(name), f)))
                                                continue;
                                        len = strlen(name);

                                        if (len == 0)
                                                continue;

                                        if (name[len-1] == '\n')
                                                name[len-1] = 0;

                                        log_debug("Adding module '%s' to hostonly module list", name);
                                        dupname = strdup(name);
                                        hashmap_put(modules_loaded, dupname, dupname);
                                }
                        }
                }

        }

        for (i = 0; i < argc; i++) {
                int r = 0;
                int ret = -1;
                log_debug("Handle module '%s'", argv[i]);

                if (argv[i][0] == '/') {
                        _cleanup_kmod_module_unref_list_ struct kmod_list *modlist = NULL;
                        _cleanup_free_ const char *modname = NULL;

                        r = kmod_module_new_from_path(ctx, argv[i], &mod_o);
                        if (r < 0) {
                                log_debug("Failed to lookup modules path '%s': %m", argv[i]);
                                if (!arg_optional)
                                        return -ENOENT;
                                continue;
                        }
                        /* Check, if we have to load another module with that name instead */
                        modname = strdup(kmod_module_get_name(mod_o));

                        if (!modname) {
                                if (!arg_optional) {
                                        if (!arg_silent)
                                                log_error("Failed to get name for module '%s'", argv[i]);
                                        return -ENOENT;
                                }
                                log_info("Failed to get name for module '%s'", argv[i]);
                                continue;
                        }

                        r = kmod_module_new_from_lookup(ctx, modname, &modlist);
                        kmod_module_unref(mod_o);
                        mod_o = NULL;

                        if (r < 0) {
                                if (!arg_optional) {
                                        if (!arg_silent)
                                                log_error("3 Failed to lookup alias '%s': %d", modname, r);
                                        return -ENOENT;
                                }
                                log_info("3 Failed to lookup alias '%s': %d", modname, r);
                                continue;
                        }
                        if (!modlist) {
                                if (!arg_optional) {
                                        if (!arg_silent)
                                                log_error("Failed to find module '%s' %s", modname, argv[i]);
                                        return -ENOENT;
                                }
                                log_info("Failed to find module '%s' %s", modname, argv[i]);
                                continue;
                        }
                        kmod_list_foreach(itr, modlist) {
                                mod = kmod_module_get_module(itr);
                                r = install_module(mod);
                                kmod_module_unref(mod);
                                if ((r < 0) && !arg_optional) {
                                        if (!arg_silent)
                                                log_error("ERROR: installing module '%s'", modname);
                                        return -ENOENT;
                                };
                                ret = ( ret == 0 ? 0 : r );
                                modinst = 1;
                        }
                } else if (argv[i][0] == '=') {
                        _cleanup_free_ char *path1 = NULL, *path2 = NULL, *path3 = NULL;
                        _cleanup_fts_close_ FTS *fts = NULL;

                        log_debug("Handling =%s", &argv[i][1]);
                        /* FIXME and add more paths*/
                        r = asprintf(&path2, "%s/kernel/%s", kerneldir, &argv[i][1]);
                        if (r < 0) {
                                log_error("Out of memory!");
                                exit(EXIT_FAILURE);
                        }

                        r = asprintf(&path1, "%s/extra/%s", kerneldir, &argv[i][1]);
                        if (r < 0) {
                                log_error("Out of memory!");
                                exit(EXIT_FAILURE);
                        }

                        r = asprintf(&path3, "%s/updates/%s", kerneldir, &argv[i][1]);
                        if (r < 0) {
                                log_error("Out of memory!");
                                exit(EXIT_FAILURE);
                        }

                        {
                                char *paths[] = { path1, path2, path3, NULL };
                                fts = fts_open(paths, FTS_COMFOLLOW|FTS_NOCHDIR|FTS_NOSTAT|FTS_LOGICAL, NULL);
                        }

                        for (FTSENT *ftsent = fts_read(fts); ftsent != NULL; ftsent = fts_read(fts)) {
                                _cleanup_kmod_module_unref_list_ struct kmod_list *modlist = NULL;
                                _cleanup_free_ const char *modname = NULL;

                                if((ftsent->fts_info == FTS_D) && !check_module_path(ftsent->fts_accpath)) {
                                        fts_set(fts, ftsent, FTS_SKIP);
                                        log_debug("Skipping %s", ftsent->fts_accpath);
                                        continue;
                                }
                                if((ftsent->fts_info != FTS_F) && (ftsent->fts_info != FTS_SL)) {
                                        log_debug("Ignoring %s", ftsent->fts_accpath);
                                        continue;
                                }
                                log_debug("Handling %s", ftsent->fts_accpath);
                                r = kmod_module_new_from_path(ctx, ftsent->fts_accpath, &mod_o);
                                if (r < 0) {
                                        log_debug("Failed to lookup modules path '%s': %m",
                                                  ftsent->fts_accpath);
                                        if (!arg_optional) {
                                                return -ENOENT;
                                        }
                                        continue;
                                }

                                /* Check, if we have to load another module with that name instead */
                                modname = strdup(kmod_module_get_name(mod_o));

                                if (!modname) {
                                        log_error("Failed to get name for module '%s'", ftsent->fts_accpath);
                                        if (!arg_optional) {
                                                return -ENOENT;
                                        }
                                        continue;
                                }
                                r = kmod_module_new_from_lookup(ctx, modname, &modlist);
                                kmod_module_unref(mod_o);
                                mod_o = NULL;

                                if (r < 0) {
                                        log_error("Failed to lookup alias '%s': %m", modname);
                                        if (!arg_optional) {
                                                return -ENOENT;
                                        }
                                        continue;
                                }

                                if (!modlist) {
                                        log_error("Failed to find module '%s' %s", modname,
                                                  ftsent->fts_accpath);
                                        if (!arg_optional) {
                                                return -ENOENT;
                                        }
                                        continue;
                                }
                                kmod_list_foreach(itr, modlist) {
                                        mod = kmod_module_get_module(itr);
                                        r = install_module(mod);
                                        kmod_module_unref(mod);
                                        if ((r < 0) && !arg_optional) {
                                                if (!arg_silent)
                                                        log_error("ERROR: installing module '%s'", modname);
                                                return -ENOENT;
                                        };
                                        ret = ( ret == 0 ? 0 : r );
                                        modinst = 1;
                                }
                        }
                        if (errno) {
                                log_error("FTS ERROR: %m");
                        }
                } else {
                        _cleanup_kmod_module_unref_list_ struct kmod_list *modlist = NULL;
                        char *modname = argv[i];

                        if (endswith(modname, ".ko")) {
                                int len = strlen(modname);
                                modname[len-3]=0;
                        }
                        if (endswith(modname, ".ko.xz") || endswith(modname, ".ko.gz")) {
                                int len = strlen(modname);
                                modname[len-6]=0;
                        }
                        r = kmod_module_new_from_lookup(ctx, modname, &modlist);
                        if (r < 0) {
                                if (!arg_optional) {
                                        if (!arg_silent)
                                                log_error("Failed to lookup alias '%s': %m", modname);
                                        return -ENOENT;
                                }
                                log_info("Failed to lookup alias '%s': %m", modname);
                                continue;
                        }
                        if (!modlist) {
                                if (!arg_optional) {
                                        if (!arg_silent)
                                                log_error("Failed to find module '%s'", modname);
                                        return -ENOENT;
                                }
                                log_info("Failed to find module '%s'", modname);
                                continue;
                        }
                        kmod_list_foreach(itr, modlist) {
                                mod = kmod_module_get_module(itr);
                                r = install_module(mod);
                                kmod_module_unref(mod);
                                if ((r < 0) && !arg_optional) {
                                        if (!arg_silent)
                                                log_error("ERROR: installing '%s'", argv[i]);
                                        return -ENOENT;
                                };
                                ret = ( ret == 0 ? 0 : r );
                                modinst = 1;
                        }
                }

                if ((modinst != 0) && (ret != 0) && (!arg_optional)) {
                        if (!arg_silent)
                                log_error("ERROR: installing '%s'", argv[i]);
                        return EXIT_FAILURE;
                }
        }

        return EXIT_SUCCESS;
}

int main(int argc, char **argv)
{
        int r;
        char *i;
        char *path = NULL;
        char *env_no_xattr = NULL;

        r = parse_argv(argc, argv);
        if (r <= 0)
                return r < 0 ? EXIT_FAILURE : EXIT_SUCCESS;

        log_set_target(LOG_TARGET_CONSOLE);
        log_parse_environment();

        if (arg_loglevel >= 0)
                log_set_max_level(arg_loglevel);

        log_open();

        modules_loaded = hashmap_new(string_hash_func, string_compare_func);
        if (arg_modalias) {
                Iterator i;
                char *name;
                _cleanup_kmod_unref_ struct kmod_ctx *ctx = NULL;
                ctx = kmod_new(kerneldir, NULL);

                modalias_list(ctx);
                HASHMAP_FOREACH(name, modules_loaded, i) {
                        printf("%s\n", name);
                }
                exit(0);
        }

        log_debug("Program arguments:");
        for (r = 0; r < argc; r++)
                log_debug("%s", argv[r]);

        path = getenv("DRACUT_INSTALL_PATH");
        if (path == NULL)
                path = getenv("PATH");

        if (path == NULL) {
                log_error("PATH is not set");
                exit(EXIT_FAILURE);
        }

        log_debug("PATH=%s", path);

        ldd = getenv("DRACUT_LDD");
        if (ldd == NULL)
                ldd = "ldd";
        log_debug("LDD=%s", ldd);

        env_no_xattr = getenv("DRACUT_NO_XATTR");
        if (env_no_xattr != NULL)
                no_xattr = true;

        pathdirs = strv_split(path, ":");

        umask(0022);

        if (destrootdir == NULL || strlen(destrootdir) == 0) {
                destrootdir = getenv("DESTROOTDIR");
                if (destrootdir == NULL || strlen(destrootdir) == 0) {
                        log_error("Environment DESTROOTDIR or argument -D is not set!");
                        usage(EXIT_FAILURE);
                }
                destrootdir = strdup(destrootdir);
        }

        if (strcmp(destrootdir, "/") == 0) {
                log_error("Environment DESTROOTDIR or argument -D is set to '/'!");
                usage(EXIT_FAILURE);
        }

        i = destrootdir;
        destrootdir = realpath(destrootdir, NULL);
        if (!destrootdir) {
                log_error("Environment DESTROOTDIR or argument -D is set to '%s': %m", i);
                r = EXIT_FAILURE;
                goto finish;
        }
        free(i);

        items = hashmap_new(string_hash_func, string_compare_func);
        items_failed = hashmap_new(string_hash_func, string_compare_func);

        if (!items || !items_failed || !modules_loaded) {
                log_error("Out of memory");
                r = EXIT_FAILURE;
                goto finish;
        }

        if (logdir) {
                int ret;

                ret = asprintf(&logfile, "%s/%d.log", logdir, getpid());
                if (ret < 0) {
                        log_error("Out of memory!");
                        exit(EXIT_FAILURE);
                }

                logfile_f = fopen(logfile, "a");
                if (logfile_f == NULL) {
                        log_error("Could not open %s for logging: %m", logfile);
                        r = EXIT_FAILURE;
                        goto finish;
                }
        }

        r = EXIT_SUCCESS;

        if (((optind + 1) < argc) && (strcmp(argv[optind + 1], destrootdir) == 0)) {
                /* ugly hack for compat mode "inst src $destrootdir" */
                if ((optind + 2) == argc) {
                        argc--;
                } else {
                        /* ugly hack for compat mode "inst src $destrootdir dst" */
                        if ((optind + 3) == argc) {
                                argc--;
                                argv[optind + 1] = argv[optind + 2];
                        }
                }
        }

        if (arg_module) {
                r = install_modules(argc - optind, &argv[optind]);
        } else if (arg_resolvelazy) {
                r = resolve_lazy(argc - optind, &argv[optind]);
        } else if (arg_all || (argc - optind > 2) || ((argc - optind) == 1)) {
                r = install_all(argc - optind, &argv[optind]);
        } else {
                /* simple "inst src dst" */
                r = install_one(argv[optind], argv[optind + 1]);
        }

        if (arg_optional)
                r = EXIT_SUCCESS;

 finish:
        if (logfile_f)
                fclose(logfile_f);

        while ((i = hashmap_steal_first(modules_loaded)))
                item_free(i);

        while ((i = hashmap_steal_first(items)))
                item_free(i);

        while ((i = hashmap_steal_first(items_failed)))
                item_free(i);

        hashmap_free(items);
        hashmap_free(items_failed);
        hashmap_free(modules_loaded);

        free(destrootdir);
        strv_free(firmwaredirs);
        strv_free(pathdirs);
        return r;
}
