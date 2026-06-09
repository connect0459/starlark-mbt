#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include "moonbit.h"
#include "vendor/isocline/include/isocline.h"

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

// Configures the line editor. Called once before the read loop. History is
// in-memory only (no filename), and isocline's own multi-line editing is
// disabled so each read returns exactly one physical line — multi-line chunk
// assembly is handled by the MoonBit-side continuation state machine.
MOONBIT_FFI_EXPORT void starlark_repl_init_editor(void) {
  ic_set_history(NULL, -1);
  ic_set_prompt_marker("", "");
  ic_enable_multiline(false);
  ic_enable_brace_insertion(false);
  ic_enable_hint(false);
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

// Reads one line from piped (non-terminal) stdin into a dynamically grown
// buffer. Returns an empty byte string for a blank line and NULL only at
// genuine end of input. isocline's own non-tty reader is not used here because
// it conflates a blank line with EOF, which would truncate multi-line input.
static moonbit_bytes_t starlark_repl_read_piped_line(void) {
  size_t cap = 256;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    return NULL;
  }
  int c;
  int saw_any = 0;
  while ((c = fgetc(stdin)) != EOF) {
    saw_any = 1;
    if (c == '\n') {
      break;
    }
    if (len + 1 >= cap) {
      cap *= 2;
      char *grown = (char *)realloc(buf, cap);
      if (grown == NULL) {
        free(buf);
        return NULL;
      }
      buf = grown;
    }
    buf[len++] = (char)c;
  }
  if (!saw_any) {
    free(buf); // EOF before any character on this line
    return NULL;
  }
  moonbit_bytes_t result = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(result, buf, len);
  }
  free(buf);
  return result;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t starlark_repl_read_line(moonbit_bytes_t prompt) {
  // On a terminal, isocline provides line editing and history (and prints the
  // prompt itself). Returns NULL only on Ctrl-D / end of input; Ctrl-C cancels
  // the current line and returns an empty string. Both paths read into a
  // dynamically grown buffer, so there is no fixed line-length limit.
  if (!isatty(STDIN_FILENO)) {
    return starlark_repl_read_piped_line();
  }
  char *line = ic_readline(prompt != NULL ? (const char *)prompt : "");
  if (line == NULL) {
    return NULL;
  }
  size_t len = strlen(line);
  moonbit_bytes_t result = moonbit_make_bytes(len, 0);
  memcpy(result, line, len);
  ic_free(line);
  return result;
}
