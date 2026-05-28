#include <time.h>
#include <stdint.h>
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
