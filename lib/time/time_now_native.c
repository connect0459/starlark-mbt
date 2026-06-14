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

/* Clamp unix_time to the range that localtime_r handles reliably.
 * Empirically, values with absolute value >= 9e16 cause localtime_r to return
 * NULL on macOS/Linux.  Clamping to ±9e15 always succeeds and returns the
 * timezone's current recurring rule, which is the correct approximation for
 * timestamps far outside the tzdata transition table. */
#define STARLARK_MAX_LOCALTIME_SEC ((int64_t)9000000000000000LL)
#define STARLARK_MIN_LOCALTIME_SEC ((int64_t)-9000000000000000LL)

static int64_t clamp_unix_time(int64_t unix_time) {
    if (unix_time > STARLARK_MAX_LOCALTIME_SEC) return STARLARK_MAX_LOCALTIME_SEC;
    if (unix_time < STARLARK_MIN_LOCALTIME_SEC) return STARLARK_MIN_LOCALTIME_SEC;
    return unix_time;
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

    time_t t = (time_t)clamp_unix_time(unix_time);
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
    time_t t = (time_t)clamp_unix_time(unix_time);
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
