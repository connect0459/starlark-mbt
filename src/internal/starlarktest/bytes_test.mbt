// Integration tests derived from bytes.star.

///|
let bytes_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|# bytes(string) -- UTF-k to UTF-8 transcoding with U+FFFD replacement
  #|hello = bytes("hello, 世界")
  #|goodbye = bytes("goodbye")
  #|empty = bytes("")
  #|nonprinting = bytes("\t\n\x7F‍")
  #|assert.eq(bytes("hello, 世界"[:-1]), b"hello, 世\xe7\x95")
  #|
  #|# bytes(iterable of int)
  #|assert.eq(bytes([65, 66, 67]), b"ABC")
  #|assert.eq(bytes((65, 66, 67)), b"ABC")
  #|assert.eq(bytes([0xf0, 0x9f, 0x98, 0xbf]), b"\xf0\x9f\x98\xbf")
  #|assert.fails(lambda: bytes([300]), "at index 0, 300 out of range")
  #|assert.fails(lambda: bytes([b"a"]), "at index 0, got bytes, want int")
  #|assert.fails(lambda: bytes(1), "want string, bytes, or iterable of ints")
  #|
  #|# literals
  #|assert.eq(b"hello, 世界", hello)
  #|assert.eq(b"goodbye", goodbye)
  #|assert.eq(b"", empty)
  #|assert.eq(b"\t\n\x7F‍", nonprinting)
  #|assert.ne("abc", b"abc")
  #|
  #|# type
  #|assert.eq(type(hello), "bytes")
  #|
  #|# len
  #|assert.eq(len(hello), 13)
  #|assert.eq(len(goodbye), 7)
  #|assert.eq(len(empty), 0)
  #|assert.eq(len(b"A"), 1)
  #|assert.eq(len(b"\xd0\x80"), 2)
  #|assert.eq(len(b"\xe4\xb8\x96"), 3)
  #|assert.eq(len(b"\xf0\x9f\x98\xbf"), 4)
  #|
  #|# truth
  #|assert.true(hello)
  #|assert.true(goodbye)
  #|assert.true(not empty)
  #|
  #|# str(bytes) does UTF-8 to UTF-k transcoding
  #|assert.eq(str(hello), "hello, 世界")
  #|assert.eq(str(goodbye), "goodbye")
  #|assert.eq(str(empty), "")
  #|assert.eq(str(nonprinting), "\t\n\x7f‍")
  #|
  #|# repr
  #|assert.eq(repr(hello), "b\"hello, 世界\"")
  #|assert.eq(repr(goodbye), "b\"goodbye\"")
  #|assert.eq(repr(empty), "b\"\"")
  #|
  #|# equality
  #|assert.eq(hello, hello)
  #|assert.ne(hello, goodbye)
  #|assert.eq(b"goodbye", goodbye)
  #|
  #|# ordered comparison
  #|assert.lt(b"abc", b"abd")
  #|assert.lt(b"abc", b"abcd")
  #|assert.lt(b"\x7f", b"\x80")
  #|
  #|# bytes are dict-hashable
  #|dict = {hello: 1, goodbye: 2}
  #|dict[b"goodbye"] = 3
  #|assert.eq(len(dict), 2)
  #|assert.eq(dict[goodbye], 3)
  #|
  #|# hash(bytes) is 32-bit FNV-1a
  #|assert.eq(hash(b""), 0x811c9dc5)
  #|assert.eq(hash(b"a"), 0xe40c292c)
  #|assert.eq(hash(b"ab"), 0x4d2505ca)
  #|assert.eq(hash(b"abc"), 0x1a47e90b)
  #|
  #|# indexing: bytes[i] returns a 1-byte bytes value
  #|assert.eq(goodbye[0], b"g")
  #|assert.eq(goodbye[-1], b"e")
  #|assert.fails(lambda: goodbye[100], "out of range")
  #|
  #|# slicing
  #|assert.eq(goodbye[:4], b"good")
  #|assert.eq(goodbye[4:], b"bye")
  #|assert.eq(goodbye[::2], b"gobe")
  #|assert.eq(goodbye[3:4], b"d")
  #|assert.eq(goodbye[4:4], b"")
  #|
  #|# bytes in bytes
  #|assert.eq(b"bc" in b"abcd", True)
  #|assert.eq(b"bc" in b"dcab", False)
  #|assert.fails(lambda: "bc" in b"dcab", "requires bytes or int as left operand, not string")
  #|
  #|# int in bytes
  #|assert.eq(97 in b"abc", True)
  #|assert.eq(100 in b"abc", False)
  #|assert.fails(lambda: 256 in b"abc", "int in bytes: 256 out of range")
  #|assert.fails(lambda: -1 in b"abc", "int in bytes: -1 out of range")
  #|
  #|# ord on bytes
  #|assert.eq(ord(b"a"), 97)
  #|assert.fails(lambda: ord(b"ab"), "ord: bytes has length 2, want 1")
  #|assert.fails(lambda: ord(b""), "ord: bytes has length 0, want 1")
  #|
  #|# repeat (bytes * int)
  #|assert.eq(goodbye * 3, b"goodbyegoodbyegoodbye")
  #|assert.eq(3 * goodbye, b"goodbyegoodbyegoodbye")
  #|
  #|# elems() returns an iterable of integer byte values
  #|assert.eq(list(hello.elems()), [104, 101, 108, 108, 111, 44, 32, 228, 184, 150, 231, 149, 140])
  #|assert.eq(bytes([104, 101, 108, 108, 111, 44, 32, 228, 184, 150, 231, 149, 140]), hello)
  #|assert.eq(list(goodbye.elems()), [103, 111, 111, 100, 98, 121, 101])
  #|assert.eq(list(empty.elems()), [])
  #|assert.eq(bytes(hello.elems()), hello)
  #|
  #|# x[i] = ... (mutation not supported)
  #|def f():
  #|    b"abc"[1] = b"B"
  #|assert.fails(f, "bytes.*does not support.*assignment")

///|
test "bytes.star: all assertions pass" {
  let errs = run_star_string(bytes_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
