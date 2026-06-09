#include <stdio.h>
#include <string.h>
#include <signal.h>
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

// Set by the SIGINT handler and polled from the evaluation loop so that a
// long-running or infinite computation can be interrupted with Ctrl-C.
static volatile sig_atomic_t starlark_repl_interrupt_flag = 0;

static void starlark_repl_sigint_handler(int signum) {
  (void)signum;
  starlark_repl_interrupt_flag = 1;
}

MOONBIT_FFI_EXPORT void starlark_repl_setup_interrupt(void) {
#ifdef _WIN32
  signal(SIGINT, starlark_repl_sigint_handler);
#else
  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_handler = starlark_repl_sigint_handler;
  sigemptyset(&sa.sa_mask);
  // No SA_RESTART: a Ctrl-C during a blocking read returns EINTR so the REPL
  // can abandon the current input line instead of treating it as EOF.
  sa.sa_flags = 0;
  sigaction(SIGINT, &sa, NULL);
#endif
}

// Reads and clears the interrupt flag (read-and-clear), so each Ctrl-C is
// observed at most once.
MOONBIT_FFI_EXPORT int starlark_repl_interrupted(void) {
  int v = (int)starlark_repl_interrupt_flag;
  starlark_repl_interrupt_flag = 0;
  return v;
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
    if (feof(stdin)) {
      return NULL; // genuine end of input (Ctrl-D)
    }
    // EINTR from a Ctrl-C (or another recoverable error): clear the stream
    // state and report NULL; the caller checks the interrupt flag to tell this
    // apart from EOF.
    clearerr(stdin);
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
