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

/* Returns UTC offset in seconds at the given Unix timestamp for the named
 * timezone. Returns INT32_MIN (0x80000000) on error or invalid timezone. */
MOONBIT_FFI_EXPORT int32_t starlark_get_tz_offset(moonbit_bytes_t name,
                                                    int64_t unix_time) {
    const char* tz_name = (const char*)name;
    const char* old_tz = getenv("TZ");
    char* old_tz_copy = old_tz ? strdup(old_tz) : NULL;

    setenv("TZ", tz_name, 1);
    tzset();

    time_t t = (time_t)unix_time;
    struct tm tm_info;
    struct tm* result = localtime_r(&t, &tm_info);
    int32_t offset;
    if (result != NULL) {
        offset = (int32_t)tm_info.tm_gmtoff;
    } else {
        offset = (int32_t)0x80000000; /* INT32_MIN = invalid */
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
