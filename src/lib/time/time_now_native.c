#include <time.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "moonbit.h"

MOONBIT_FFI_EXPORT int64_t starlark_time_get_unix_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (int64_t)ts.tv_sec;
}

MOONBIT_FFI_EXPORT int32_t starlark_time_get_unix_nsec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (int32_t)ts.tv_nsec;
}

/* Returns 1 if the IANA timezone file exists, 0 otherwise */
MOONBIT_FFI_EXPORT int32_t starlark_is_valid_timezone(moonbit_bytes_t name) {
    char path[512];
    snprintf(path, sizeof(path), "/usr/share/zoneinfo/%s", (const char*)name);
    FILE* f = fopen(path, "rb");
    if (f) {
        fclose(f);
        return 1;
    }
    return 0;
}

/* Maximum absolute Unix second that localtime_r handles on this platform.
 * On macOS/Linux with 64-bit time_t the empirical failure boundary is near
 * ±6.7×10¹⁶ s; ±6×10¹⁶ provides ~10% headroom. */
#define STARLARK_LOCALTIME_LIMIT ((int64_t)60000000000000000LL)

/* Return a timestamp that (a) localtime_r can handle and (b) shares the same
 * Julian-year phase as unix_time, so the recurring DST rule is evaluated in
 * the correct season.  For timestamps already within ±LIMIT this is a no-op.
 *
 * Julian year: 365.25 × 86400 = 31 557 600 s.  For timestamps beyond ±LIMIT
 * we find the nearest same-phase instant inside [0, LIMIT] — this applies
 * the modern recurring rule (correct for far-future timestamps) rather than
 * the fixed boundary point (which may land in the opposite DST season).
 *
 * Known limitation: for far-past timestamps (beyond −LIMIT) this also
 * returns a modern-era value; systems that use LMT for pre-historical times
 * will therefore return the modern recurring-rule offset instead of LMT. */
static int64_t safe_localtime_sec(int64_t unix_time) {
    if (unix_time >= -STARLARK_LOCALTIME_LIMIT && unix_time <= STARLARK_LOCALTIME_LIMIT)
        return unix_time;
    const int64_t year_sec = 31557600LL;
    int64_t pos = unix_time % year_sec;
    if (pos < 0) pos += year_sec;
    int64_t t = (STARLARK_LOCALTIME_LIMIT / year_sec) * year_sec + pos;
    if (t > STARLARK_LOCALTIME_LIMIT) t -= year_sec;
    return t;
}

/* Returns UTC offset for the named timezone at unix_time, writing the zone
 * abbreviation (at most 15 chars + NUL) into abbr_out.
 * Returns INT32_MIN on error or invalid timezone. */
MOONBIT_FFI_EXPORT int32_t starlark_get_tz_abbr(moonbit_bytes_t name,
                                                  int64_t unix_time,
                                                  moonbit_bytes_t abbr_out) {
    const char* tz_name = (const char*)name;
    const char* old_tz = getenv("TZ");
    char* old_tz_copy = old_tz ? strdup(old_tz) : NULL;

    setenv("TZ", tz_name, 1);
    tzset();

    time_t t = (time_t)safe_localtime_sec(unix_time);
    struct tm tm_info;
    struct tm* result = localtime_r(&t, &tm_info);
    int32_t offset;
    if (result != NULL) {
        offset = (int32_t)tm_info.tm_gmtoff;
        if (tm_info.tm_zone) {
            strncpy((char*)abbr_out, tm_info.tm_zone, 15);
            ((char*)abbr_out)[15] = '\0';
        } else {
            ((char*)abbr_out)[0] = '\0';
        }
    } else {
        offset = (int32_t)0x80000000;
        ((char*)abbr_out)[0] = '\0';
    }

    if (old_tz_copy) {
        setenv("TZ", old_tz_copy, 1);
        free(old_tz_copy);
    } else {
        unsetenv("TZ");
    }
    tzset();

    return offset;
}

/* Returns UTC offset for the host's local timezone at unix_time, writing the
 * zone abbreviation into abbr_out.
 * Returns INT32_MIN on error. */
MOONBIT_FFI_EXPORT int32_t starlark_get_local_tz_at(int64_t unix_time,
                                                      moonbit_bytes_t abbr_out) {
    time_t t = (time_t)safe_localtime_sec(unix_time);
    struct tm tm_info;
    struct tm* result = localtime_r(&t, &tm_info);
    if (result != NULL) {
        if (tm_info.tm_zone) {
            strncpy((char*)abbr_out, tm_info.tm_zone, 15);
            ((char*)abbr_out)[15] = '\0';
        } else {
            ((char*)abbr_out)[0] = '\0';
        }
        return (int32_t)tm_info.tm_gmtoff;
    }
    ((char*)abbr_out)[0] = '\0';
    return (int32_t)0x80000000;
}
