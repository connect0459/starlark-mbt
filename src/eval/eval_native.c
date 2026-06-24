#include <stdio.h>
#include "moonbit.h"

MOONBIT_FFI_EXPORT void starlark_println_bytes(moonbit_bytes_t data,
                                               int32_t len) {
  fwrite(data, 1, (size_t)len, stdout);
  fputc('\n', stdout);
}
