#undef _LARGEFILE_SOURCE
#undef _FILE_OFFSET_BITS
#define _LARGEFILE_SOURCE
#define _FILE_OFFSET_BITS 64
#if defined(__PPC__) && !defined(__powerpc__)
#define __powerpc__ 1
#endif

#define GCRYPT_NO_DEPRECATED 1
#define HAVE_MEMMOVE 1

#if 0
#define MM_DEBUG 0
#endif

/* Define to 1 to enable disk cache statistics.  */
#define DISK_CACHE_STATS 0
#define BOOT_TIME_STATS 0
/* Define to 1 to make GRUB quieter at boot time.  */
#define QUIET_BOOT 0

/* We don't need those.  */
#define MINILZO_CFG_SKIP_LZO_PTR 1
#define MINILZO_CFG_SKIP_LZO_UTIL 1
#define MINILZO_CFG_SKIP_LZO_STRING 1
#define MINILZO_CFG_SKIP_LZO_INIT 1
#define MINILZO_CFG_SKIP_LZO1X_1_COMPRESS 1
#define MINILZO_CFG_SKIP_LZO1X_DECOMPRESS 1

#if defined (GRUB_BUILD)
#  undef ENABLE_NLS
#  define BUILD_SIZEOF_LONG 8
#  define BUILD_SIZEOF_VOID_P 8
#  if defined __APPLE__
#    if defined __BIG_ENDIAN__
#      define BUILD_WORDS_BIGENDIAN 1
#    else
#      define BUILD_WORDS_BIGENDIAN 0
#    endif
#  else /* !defined __APPLE__ */
#    define BUILD_WORDS_BIGENDIAN 0
#  endif /* !defined __APPLE__ */
#elif defined (GRUB_UTIL) || !defined (GRUB_MACHINE)
#  include <config-util.h>
#else /* !defined GRUB_UTIL && defined GRUB_MACHINE */
#  define HAVE_FONT_SOURCE 1
/* Define if C symbols get an underscore after compilation. */
#  define HAVE_ASM_USCORE 0
/* Define it to one of __bss_start, edata and _edata.  */
#  define BSS_START_SYMBOL 
/* Define it to either end or _end.  */
#  define END_SYMBOL 
/* Name of package.  */
#  define PACKAGE "grub"
/* Version number of package.  */
#  define VERSION "2.12"
/* Define to the full name and version of this package. */
#  define PACKAGE_STRING "GRUB 2.12-9"
/* Define to the version of this package. */
#  define PACKAGE_VERSION "2.12-9"
/* Define to the full name of this package. */
#  define PACKAGE_NAME "GRUB"
/* Define to the address where bug reports for this package should be sent. */
#  define PACKAGE_BUGREPORT "bug-grub@gnu.org"

#  define GRUB_TARGET_CPU "x86_64"
#  define GRUB_PLATFORM "efi"

#  define GRUB_STACK_PROTECTOR_INIT 

#  define RE_ENABLE_I18N 1

#  define _GNU_SOURCE 1

#  ifndef _GL_INLINE_HEADER_BEGIN
/*
 * gnulib gets configured against the host, not the target, and the rest of
 * our buildsystem works around that.  This is difficult to avoid as gnulib's
 * detection requires a more capable system than our target.  Instead, we
 * reach in and set values appropriately - intentionally setting more than the
 * bare minimum.  If, when updating gnulib, something breaks, there's probably
 * a change needed here or in grub-core/Makefile.core.def.
 */
#    define SIZE_MAX ((size_t) -1)
#    define _GL_ATTRIBUTE_ALLOC_SIZE(args) \
    __attribute__ ((__alloc_size__ args))
#    define _GL_ATTRIBUTE_ALWAYS_INLINE __attribute__ ((__always_inline__))
#    define _GL_ATTRIBUTE_ARTIFICIAL __attribute__ ((__artificial__))
#    define _GL_ATTRIBUTE_COLD __attribute__ ((cold))
#    define _GL_ATTRIBUTE_CONST __attribute__ ((const))
#    define _GL_ATTRIBUTE_DEALLOC(f, i) __attribute ((__malloc__ (f, i)))
#    define _GL_ATTRIBUTE_DEALLOC_FREE _GL_ATTRIBUTE_DEALLOC (free, 1)
#    define _GL_ATTRIBUTE_DEPRECATED __attribute__ ((__deprecated__))
#    define _GL_ATTRIBUTE_ERROR(msg) __attribute__ ((__error__ (msg)))
#    define _GL_ATTRIBUTE_EXTERNALLY_VISIBLE \
    __attribute__ ((externally_visible))
#    define _GL_ATTRIBUTE_FORMAT(spec) __attribute__ ((__format__ spec))
#    define _GL_ATTRIBUTE_LEAF __attribute__ ((__leaf__))
#    define _GL_ATTRIBUTE_MALLOC __attribute__ ((malloc))
#    define _GL_ATTRIBUTE_MAYBE_UNUSED _GL_ATTRIBUTE_UNUSED
#    define _GL_ATTRIBUTE_MAY_ALIAS __attribute__ ((__may_alias__))
#    define _GL_ATTRIBUTE_NODISCARD __attribute__ ((__warn_unused_result__))
#    define _GL_ATTRIBUTE_NOINLINE __attribute__ ((__noinline__))
#    define _GL_ATTRIBUTE_NONNULL(args) __attribute__ ((__nonnull__ args))
#    define _GL_ATTRIBUTE_NONSTRING __attribute__ ((__nonstring__))
#    define _GL_ATTRIBUTE_PACKED __attribute__ ((__packed__))
#    define _GL_ATTRIBUTE_PURE __attribute__ ((__pure__))
#    define _GL_ATTRIBUTE_RETURNS_NONNULL \
    __attribute__ ((__returns_nonnull__))
#    define _GL_ATTRIBUTE_SENTINEL(pos) __attribute__ ((__sentinel__ pos))
#    define _GL_ATTRIBUTE_UNUSED __attribute__ ((__unused__))
#    define _GL_ATTRIBUTE_WARNING(msg) __attribute__ ((__warning__ (msg)))
#    define _GL_CMP(n1, n2) (((n1) > (n2)) - ((n1) < (n2)))
#    define _GL_GNUC_PREREQ GNUC_PREREQ
#    define _GL_INLINE inline
#    define _GL_UNUSED_LABEL _GL_ATTRIBUTE_UNUSED

/* We can't use __has_attribute for these because gcc-5.1 is too old for
 * that.  Everything above is present in that version, though. */
#    if __GNUC__ >= 7
#      define _GL_ATTRIBUTE_FALLTHROUGH __attribute__ ((fallthrough))
#    else
#      define _GL_ATTRIBUTE_FALLTHROUGH /* empty */
#    endif

#    ifndef ASM_FILE
typedef __INT_FAST32_TYPE__ int_fast32_t;
typedef __UINT_FAST32_TYPE__ uint_fast32_t;
#    endif

/* Ensure ialloc nests static/non-static inline properly. */
#    define IALLOC_INLINE static inline

/*
 * gnulib uses these for blocking out warnings they can't/won't fix.  gnulib
 * also makes the decision about whether to provide a declaration for
 * reallocarray() at compile-time, so this is a convenient place to override -
 * it's used by the ialloc module, which is used by base64.
 */
#    define _GL_INLINE_HEADER_BEGIN _Pragma ("GCC diagnostic push")	\
    void *								\
    reallocarray (void *ptr, unsigned int nmemb, unsigned int size);
#    define _GL_INLINE_HEADER_END   _Pragma ("GCC diagnostic pop")
#  endif /* !_GL_INLINE_HEADER_BEGIN */

/* gnulib doesn't build cleanly with older compilers. */
#  if __GNUC__ < 11
_Pragma ("GCC diagnostic ignored \"-Wtype-limits\"")
#  endif

#endif
