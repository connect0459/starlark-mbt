/**
 * Minimal Node.js example: load the starlark wasm_api module and call exec_script.
 *
 * Build the wasm module first:
 *   cd examples && moon build wasm_api --target wasm-gc --release
 *
 * Run (from the repository root):
 *   node examples/wasm_api/usage.js
 *
 * Requires Node.js >= 22 (WebAssembly GC + JS String Builtins support).
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const wasmPath = join(
  __dirname,
  '../_build/wasm-gc/release/build/wasm_api/wasm_api.wasm',
);

const bytes = readFileSync(wasmPath);

// The wasm-gc module compiled with use-js-builtin-string:true requires:
//
//   builtins: ['js-string']   – resolved by the WebAssembly runtime
//   _.*                       – interned string-constant globals embedded in
//                               the binary; each is imported by its text value
//   console.log               – used by MoonBit's println (unused here because
//                               the exec_script print callback captures output)
//
// A Proxy on the '_' namespace makes every string-constant import self-resolve:
const strings = new Proxy(
  {},
  { get: (_target, name) => name },
);

const mod = await WebAssembly.compile(bytes, { builtins: ['js-string'] });
const instance = await WebAssembly.instantiate(mod, {
  _: strings,
  console: { log: console.log },
});

// exec_script accepts a Starlark source string and returns a JSON string.
// Default dialect: allow_set, allow_lambda, allow_bytes, allow_float all true;
// top-level for/while/if and recursion disabled.
const result = instance.exports.exec_script(`
greeting = "hello from wasm-gc Starlark!"
numbers  = [1, 2, 3, 4, 5]
total    = len([x for x in numbers])  # count via comprehension
squares  = [x * x for x in numbers]
print("greeting:", greeting)
print("squares:", squares)
`);

const data = JSON.parse(result);

if (data.error) {
  console.error('Starlark error:', data.error);
} else {
  console.log('output :', data.output.trim());
  console.log('globals:', JSON.stringify(data.globals, null, 2));
}

// exec_script_with_env accepts a Starlark source string and a JSON object
// string.  Keys in the JSON object become read-only predeclared names inside
// the script; they are not listed in the returned "globals" map.  Supported
// value types: null, bool, number, string, array, object (any JSON value that
// maps to a Starlark value).
const envJson = JSON.stringify({
  APP_NAME: 'my-app',
  VERSION: 3,
  FEATURES: ['alpha', 'beta'],
});

const result2 = instance.exports.exec_script_with_env(
  `
label = APP_NAME + " v" + str(VERSION)
feature_count = len(FEATURES)
print("label:", label)
`,
  envJson,
);

const data2 = JSON.parse(result2);

if (data2.error) {
  console.error('Starlark error:', data2.error);
} else {
  console.log('output :', data2.output.trim());
  console.log('globals:', JSON.stringify(data2.globals, null, 2));
}

// exec_script_with_options accepts a Starlark source string and a JSON object
// string that configures dialect flags.  Recognised keys (all boolean):
//   allow_set, allow_recursion, allow_lambda, allow_while, allow_bytes,
//   allow_float, allow_global_reassign, allow_top_level_control,
//   load_binds_globally.
// Missing keys default to Options::default().  Unknown keys or non-boolean
// values produce {"error":"..."} instead of silently falling back.
const optionsJson = JSON.stringify({
  allow_recursion: true,
  allow_top_level_control: true,
});

const result3 = instance.exports.exec_script_with_options(
  `
def fib(n):
  if n <= 1:
    return n
  return fib(n - 1) + fib(n - 2)

results = [fib(i) for i in range(8)]
print("fibonacci:", results)
`,
  optionsJson,
);

const data3 = JSON.parse(result3);

if (data3.error) {
  console.error('Starlark error:', data3.error);
} else {
  console.log('output :', data3.output.trim());
  console.log('globals:', JSON.stringify(data3.globals, null, 2));
}
