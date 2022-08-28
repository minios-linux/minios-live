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

#include <stdarg.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stddef.h>

#include "log.h"
#include "util.h"
#include "macro.h"

#define SNDBUF_SIZE (8*1024*1024)

static LogTarget log_target = LOG_TARGET_CONSOLE;
static int log_max_level = LOG_WARNING;
static int log_facility = LOG_DAEMON;

static int console_fd = STDERR_FILENO;

static bool show_location = false;

/* Akin to glibc's __abort_msg; which is private and we hence cannot
 * use here. */
static char *log_abort_msg = NULL;

void log_close_console(void) {

        if (console_fd < 0)
                return;

        if (getpid() == 1) {
                if (console_fd >= 3)
                        close_nointr_nofail(console_fd);

                console_fd = -1;
        }
}

static int log_open_console(void) {

        if (console_fd >= 0)
                return 0;

        if (getpid() == 1) {

                console_fd = open_terminal("/dev/console", O_WRONLY|O_NOCTTY|O_CLOEXEC);
                if (console_fd < 0) {
                        log_error("Failed to open /dev/console for logging: %s", strerror(-console_fd));
                        return console_fd;
                }

                log_debug("Successfully opened /dev/console for logging.");
        } else
                console_fd = STDERR_FILENO;

        return 0;
}


int log_open(void) {
        return log_open_console();
}


void log_close(void) {
        log_close_console();
}


void log_set_max_level(int level) {
        assert((level & LOG_PRIMASK) == level);

        log_max_level = level;
}

void log_set_facility(int facility) {
        log_facility = facility;
}

static int write_to_console(
                int level,
                const char*file,
                unsigned int line,
                const char *func,
                const char *buffer) {

        struct iovec iovec[5];
        unsigned n = 0;

        if (console_fd < 0)
                return 0;

        zero(iovec);

        IOVEC_SET_STRING(iovec[n++], "dracut-install: ");

        if (show_location) {
                char location[64];
                if (snprintf(location, sizeof(location), "(%s:%u) ", file, line) <= 0)
                        return -errno;
                IOVEC_SET_STRING(iovec[n++], location);
        }

        IOVEC_SET_STRING(iovec[n++], buffer);
        IOVEC_SET_STRING(iovec[n++], "\n");

        if (writev(console_fd, iovec, n) < 0)
                return -errno;

        return 1;
}

static int log_dispatch(
        int level,
        const char*file,
        int line,
        const char *func,
        char *buffer) {

        int r = 0;

        if (log_target == LOG_TARGET_NULL)
                return 0;

        /* Patch in LOG_DAEMON facility if necessary */
        if ((level & LOG_FACMASK) == 0)
                level = log_facility | LOG_PRI(level);

        do {
                char *e;
                int k = 0;

                buffer += strspn(buffer, NEWLINE);

                if (buffer[0] == 0)
                        break;

                if ((e = strpbrk(buffer, NEWLINE)))
                        *(e++) = 0;

                k = write_to_console(level, file, line, func, buffer);
                if (k < 0)
                        return k;
                buffer = e;
        } while (buffer);

        return r;
}

int log_metav(
        int level,
        const char*file,
        int line,
        const char *func,
        const char *format,
        va_list ap) {

        char buffer[LINE_MAX];
        int saved_errno, r;

        if (_likely_(LOG_PRI(level) > log_max_level))
                return 0;

        saved_errno = errno;
        vsnprintf(buffer, sizeof(buffer), format, ap);
        char_array_0(buffer);

        r = log_dispatch(level, file, line, func, buffer);
        errno = saved_errno;

        return r;
}

int log_meta(
        int level,
        const char*file,
        int line,
        const char *func,
        const char *format, ...) {

        int r;
        va_list ap;

        va_start(ap, format);
        r = log_metav(level, file, line, func, format, ap);
        va_end(ap);

        return r;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-nonliteral"
_noreturn_ static void log_assert(const char *text, const char *file, int line, const char *func, const char *format) {
        static char buffer[LINE_MAX];

        snprintf(buffer, sizeof(buffer), format, text, file, line, func);

        char_array_0(buffer);
        log_abort_msg = buffer;

        log_dispatch(LOG_CRIT, file, line, func, buffer);
        abort();
}
#pragma GCC diagnostic pop

_noreturn_ void log_assert_failed(const char *text, const char *file, int line, const char *func) {
        log_assert(text, file, line, func, "Assertion '%s' failed at %s:%u, function %s(). Aborting.");
}

_noreturn_ void log_assert_failed_unreachable(const char *text, const char *file, int line, const char *func) {
        log_assert(text, file, line, func, "Code should not be reached '%s' at %s:%u, function %s(). Aborting.");
}

void log_set_target(LogTarget target) {
        assert(target >= 0);
        assert(target < _LOG_TARGET_MAX);

        log_target = target;
}

int log_set_target_from_string(const char *e) {
        LogTarget t;

        t = log_target_from_string(e);
        if (t < 0)
                return -EINVAL;

        log_set_target(t);
        return 0;
}

int log_set_max_level_from_string(const char *e) {
        int t;

        t = log_level_from_string(e);
        if (t < 0)
                return t;

        log_set_max_level(t);
        return 0;
}

void log_parse_environment(void) {
        const char *e;

        if ((e = getenv("DRACUT_INSTALL_LOG_TARGET"))) {
                if (log_set_target_from_string(e) < 0)
                        log_warning("Failed to parse log target %s. Ignoring.", e);
        } else if ((e = getenv("DRACUT_LOG_TARGET"))) {
                if (log_set_target_from_string(e) < 0)
                        log_warning("Failed to parse log target %s. Ignoring.", e);
        }

        if ((e = getenv("DRACUT_INSTALL_LOG_LEVEL"))) {
                if (log_set_max_level_from_string(e) < 0)
                        log_warning("Failed to parse log level %s. Ignoring.", e);
        } else if ((e = getenv("DRACUT_LOG_LEVEL"))) {
                if (log_set_max_level_from_string(e) < 0)
                        log_warning("Failed to parse log level %s. Ignoring.", e);
        }
}

LogTarget log_get_target(void) {
        return log_target;
}

int log_get_max_level(void) {
        return log_max_level;
}


static const char *const log_target_table[] = {
        [LOG_TARGET_CONSOLE] = "console",
        [LOG_TARGET_AUTO] = "auto",
        [LOG_TARGET_SAFE] = "safe",
        [LOG_TARGET_NULL] = "null"
};

DEFINE_STRING_TABLE_LOOKUP(log_target, LogTarget);
