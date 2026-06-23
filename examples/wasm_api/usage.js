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
// top-level for/while/if and recursion disabled (pass options via exec_file for
// custom dialects – this thin wrapper always uses Options::default()).
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
