/***
  This file is part of systemd.

  Copyright 2010 Lennart Poettering

  systemd is free software; you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation; either version 2.1 of the License, or
  (at your option) any later version.

  systemd is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with systemd; If not, see <http://www.gnu.org/licenses/>.
***/

#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/syscall.h>

#include "util.h"

static inline pid_t gettid(void) {
        return (pid_t) syscall(SYS_gettid);
}

size_t page_size(void) {
        static __thread size_t pgsz = 0;
        long r;

        if (_likely_(pgsz > 0))
                return pgsz;

        assert_se((r = sysconf(_SC_PAGESIZE)) > 0);

        pgsz = (size_t) r;

        return pgsz;
}

bool endswith(const char *s, const char *postfix) {
        size_t sl, pl;

        assert(s);
        assert(postfix);

        sl = strlen(s);
        pl = strlen(postfix);

        if (pl == 0)
                return true;

        if (sl < pl)
                return false;

        return memcmp(s + sl - pl, postfix, pl) == 0;
}
int close_nointr(int fd) {
        assert(fd >= 0);

        for (;;) {
                int r;

                r = close(fd);
                if (r >= 0)
                        return r;

                if (errno != EINTR)
                        return -errno;
        }
}

void close_nointr_nofail(int fd) {
        int saved_errno = errno;

        /* like close_nointr() but cannot fail, and guarantees errno
         * is unchanged */

        assert_se(close_nointr(fd) == 0);

        errno = saved_errno;
}

int open_terminal(const char *name, int mode) {
        int fd, r;
        unsigned c = 0;

        /*
         * If a TTY is in the process of being closed opening it might
         * cause EIO. This is horribly awful, but unlikely to be
         * changed in the kernel. Hence we work around this problem by
         * retrying a couple of times.
         *
         * https://bugs.launchpad.net/ubuntu/+source/linux/+bug/554172/comments/245
         */

        for (;;) {
                if ((fd = open(name, mode)) >= 0)
                        break;

                if (errno != EIO)
                        return -errno;

                if (c >= 20)
                        return -errno;

                usleep(50 * USEC_PER_MSEC);
                c++;
        }

        if (fd < 0)
                return -errno;

        if ((r = isatty(fd)) < 0) {
                close_nointr_nofail(fd);
                return -errno;
        }

        if (!r) {
                close_nointr_nofail(fd);
                return -ENOTTY;
        }

        return fd;
}

bool streq_ptr(const char *a, const char *b) {

        /* Like streq(), but tries to make sense of NULL pointers */

        if (a && b)
                return streq(a, b);

        if (!a && !b)
                return true;

        return false;
}
bool is_main_thread(void) {
        static __thread int cached = 0;

        if (_unlikely_(cached == 0))
                cached = getpid() == gettid() ? 1 : -1;

        return cached > 0;
}

int safe_atou(const char *s, unsigned *ret_u) {
        char *x = NULL;
        unsigned long l;

        assert(s);
        assert(ret_u);

        errno = 0;
        l = strtoul(s, &x, 0);

        if (!x || *x || errno)
                return errno ? -errno : -EINVAL;

        if ((unsigned long) (unsigned) l != l)
                return -ERANGE;

        *ret_u = (unsigned) l;
        return 0;
}

static const char *const log_level_table[] = {
        [LOG_EMERG] = "emerg",
        [LOG_ALERT] = "alert",
        [LOG_CRIT] = "crit",
        [LOG_ERR] = "err",
        [LOG_WARNING] = "warning",
        [LOG_NOTICE] = "notice",
        [LOG_INFO] = "info",
        [LOG_DEBUG] = "debug"
};

DEFINE_STRING_TABLE_LOOKUP(log_level, int);

char *strnappend(const char *s, const char *suffix, size_t b) {
        size_t a;
        char *r;

        if (!s && !suffix)
                return strdup("");

        if (!s)
                return strndup(suffix, b);

        if (!suffix)
                return strdup(s);

        assert(s);
        assert(suffix);

        a = strlen(s);
        if (b > ((size_t) -1) - a)
                return NULL;

        r = new(char, a+b+1);
        if (!r)
                return NULL;

        memcpy(r, s, a);
        memcpy(r+a, suffix, b);
        r[a+b] = 0;

        return r;
}

char *strappend(const char *s, const char *suffix) {
        return strnappend(s, suffix, suffix ? strlen(suffix) : 0);
}

char *strjoin(const char *x, ...) {
        va_list ap;
        size_t l;
        char *r;

        va_start(ap, x);

        if (x) {
                l = strlen(x);

                for (;;) {
                        const char *t;
                        size_t n;

                        t = va_arg(ap, const char *);
                        if (!t)
                                break;

                        n = strlen(t);
                        if (n > ((size_t) -1) - l) {
                                va_end(ap);
                                return NULL;
                        }

                        l += n;
                }
        } else
                l = 0;

        va_end(ap);

        r = new(char, l+1);
        if (!r)
                return NULL;

        if (x) {
                char *p;

                p = stpcpy(r, x);

                va_start(ap, x);

                for (;;) {
                        const char *t;

                        t = va_arg(ap, const char *);
                        if (!t)
                                break;

                        p = stpcpy(p, t);
                }

                va_end(ap);
        } else
                r[0] = 0;

        return r;
}

char *cunescape_length_with_prefix(const char *s, size_t length, const char *prefix) {
        char *r, *t;
        const char *f;
        size_t pl;

        assert(s);

        /* Undoes C style string escaping, and optionally prefixes it. */

        pl = prefix ? strlen(prefix) : 0;

        r = new(char, pl+length+1);
        if (!r)
                return r;

        if (prefix)
                memcpy(r, prefix, pl);

        for (f = s, t = r + pl; f < s + length; f++) {

                if (*f != '\\') {
                        *(t++) = *f;
                        continue;
                }

                f++;

                switch (*f) {

                case 'a':
                        *(t++) = '\a';
                        break;
                case 'b':
                        *(t++) = '\b';
                        break;
                case 'f':
                        *(t++) = '\f';
                        break;
                case 'n':
                        *(t++) = '\n';
                        break;
                case 'r':
                        *(t++) = '\r';
                        break;
                case 't':
                        *(t++) = '\t';
                        break;
                case 'v':
                        *(t++) = '\v';
                        break;
                case '\\':
                        *(t++) = '\\';
                        break;
                case '"':
                        *(t++) = '"';
                        break;
                case '\'':
                        *(t++) = '\'';
                        break;

                case 's':
                        /* This is an extension of the XDG syntax files */
                        *(t++) = ' ';
                        break;

                case 'x': {
                        /* hexadecimal encoding */
                        int a, b;

                        a = unhexchar(f[1]);
                        b = unhexchar(f[2]);

                        if (a < 0 || b < 0) {
                                /* Invalid escape code, let's take it literal then */
                                *(t++) = '\\';
                                *(t++) = 'x';
                        } else {
                                *(t++) = (char) ((a << 4) | b);
                                f += 2;
                        }

                        break;
                }

                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7': {
                        /* octal encoding */
                        int a, b, c;

                        a = unoctchar(f[0]);
                        b = unoctchar(f[1]);
                        c = unoctchar(f[2]);

                        if (a < 0 || b < 0 || c < 0) {
                                /* Invalid escape code, let's take it literal then */
                                *(t++) = '\\';
                                *(t++) = f[0];
                        } else {
                                *(t++) = (char) ((a << 6) | (b << 3) | c);
                                f += 2;
                        }

                        break;
                }

                case 0:
                        /* premature end of string.*/
                        *(t++) = '\\';
                        goto finish;

                default:
                        /* Invalid escape code, let's take it literal then */
                        *(t++) = '\\';
                        *(t++) = *f;
                        break;
                }
        }

finish:
        *t = 0;
        return r;
}

char *cunescape_length(const char *s, size_t length) {
        return cunescape_length_with_prefix(s, length, NULL);
}


/* Split a string into words, but consider strings enclosed in '' and
 * "" as words even if they include spaces. */
char *split_quoted(const char *c, size_t *l, char **state) {
        const char *current, *e;
        bool escaped = false;

        assert(c);
        assert(l);
        assert(state);

        current = *state ? *state : c;

        current += strspn(current, WHITESPACE);

        if (*current == 0)
                return NULL;

        else if (*current == '\'') {
                current ++;

                for (e = current; *e; e++) {
                        if (escaped)
                                escaped = false;
                        else if (*e == '\\')
                                escaped = true;
                        else if (*e == '\'')
                                break;
                }

                *l = e-current;
                *state = (char*) (*e == 0 ? e : e+1);

        } else if (*current == '\"') {
                current ++;

                for (e = current; *e; e++) {
                        if (escaped)
                                escaped = false;
                        else if (*e == '\\')
                                escaped = true;
                        else if (*e == '\"')
                                break;
                }

                *l = e-current;
                *state = (char*) (*e == 0 ? e : e+1);

        } else {
                for (e = current; *e; e++) {
                        if (escaped)
                                escaped = false;
                        else if (*e == '\\')
                                escaped = true;
                        else if (strchr(WHITESPACE, *e))
                                break;
                }
                *l = e-current;
                *state = (char*) e;
        }

        return (char*) current;
}

/* Split a string into words. */
char *split(const char *c, size_t *l, const char *separator, char **state) {
        char *current;

        current = *state ? *state : (char*) c;

        if (!*current || *c == 0)
                return NULL;

        current += strspn(current, separator);
        *l = strcspn(current, separator);
        *state = current+*l;

        return (char*) current;
}

int unhexchar(char c) {

        if (c >= '0' && c <= '9')
                return c - '0';

        if (c >= 'a' && c <= 'f')
                return c - 'a' + 10;

        if (c >= 'A' && c <= 'F')
                return c - 'A' + 10;

        return -1;
}

int unoctchar(char c) {

        if (c >= '0' && c <= '7')
                return c - '0';

        return -1;
}
