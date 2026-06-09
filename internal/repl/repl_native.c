#include <stdio.h>
#include <string.h>
#include "moonbit.h"

#ifdef _WIN32
#include <io.h>
#define isatty _isatty
#define STDIN_FILENO 0
#else
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT int starlark_repl_isatty(void) {
  return isatty(STDIN_FILENO);
}

MOONBIT_FFI_EXPORT void starlark_repl_write_stderr(moonbit_bytes_t s) {
  if (s != NULL) {
    fputs((const char *)s, stderr);
  }
  fflush(stderr);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t starlark_repl_read_line(moonbit_bytes_t prompt) {
  if (prompt != NULL && prompt[0] != '\0') {
    // Prompts go to stderr so piped stdout stays clean (as starlark-go does).
    fputs((const char *)prompt, stderr);
    fflush(stderr);
  }
  char buf[4096];
  if (fgets(buf, sizeof(buf), stdin) == NULL) {
    return NULL;
  }
  size_t len = strlen(buf);
  if (len > 0 && buf[len - 1] == '\n') {
    buf[--len] = '\0';
  }
  moonbit_bytes_t result = moonbit_make_bytes(len, 0);
  memcpy(result, buf, len);
  return result;
}
