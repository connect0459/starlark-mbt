// Integration tests derived from starlark-go string.star.
// Regex patterns in assert.fails are simplified to plain substrings.
// Unicode-specific byte-index tests and codepoints type-check tests are excluded.

///|
let string_star_src : String =
  #|load("assert.star", "assert")
  #|
  #|# raw string literals
  #|assert.eq(r"a\bc", "a\\bc")
  #|
  #|# truth
  #|assert.true("abc")
  #|assert.true(not "")
  #|
  #|# str + str
  #|assert.eq("a" + "b" + "c", "abc")
  #|
  #|# str * int, int * str
  #|assert.eq("abc" * 0, "")
  #|assert.eq("abc" * -1, "")
  #|assert.eq("abc" * 1, "abc")
  #|assert.eq("abc" * 5, "abcabcabcabcabc")
  #|assert.eq(0 * "abc", "")
  #|assert.eq(-1 * "abc", "")
  #|assert.eq(1 * "abc", "abc")
  #|assert.eq(5 * "abc", "abcabcabcabcabc")
  #|assert.fails(lambda: 1.0 * "abc", "unsupported operand types for *")
  #|
  #|# len (ASCII only)
  #|assert.eq(len("Hello"), 5)
  #|assert.eq(len(""), 0)
  #|
  #|# chr & ord
  #|assert.eq(chr(65), "A")
  #|assert.eq(chr(97), "a")
  #|assert.fails(lambda: chr(-1), "not in range")
  #|assert.fails(lambda: chr(0x110000), "not in range")
  #|assert.eq(ord("A"), 0x41)
  #|assert.fails(lambda: ord("abc"), "expected a character")
  #|assert.fails(lambda: ord(""), "expected a character")
  #|
  #|# codepoint_ords returns a list in this implementation
  #|assert.eq(list("abc".codepoint_ords()), [97, 98, 99])
  #|assert.eq(list("".codepoint_ords()), [])
  #|
  #|# codepoints returns a list
  #|assert.eq(list("abc".codepoints()), ["a", "b", "c"])
  #|assert.eq(list("".codepoints()), [])
  #|
  #|# elem_ords returns a list of byte values
  #|assert.eq(list("abc".elem_ords()), [97, 98, 99])
  #|assert.eq(list("".elem_ords()), [])
  #|
  #|# indexing, x[i]
  #|assert.eq("Hello"[0], "H")
  #|assert.fails(lambda: "abc"[-4], "out of range")
  #|assert.eq("abc"[-3], "a")
  #|assert.eq("abc"[-2], "b")
  #|assert.eq("abc"[-1], "c")
  #|assert.eq("abc"[0], "a")
  #|assert.eq("abc"[1], "b")
  #|assert.eq("abc"[2], "c")
  #|assert.fails(lambda: "abc"[4], "out of range")
  #|
  #|# x[i] = ... must fail
  #|def f():
  #|    "abc"[1] = "B"
  #|assert.fails(f, "does not support")
  #|
  #|# slicing, x[i:j]
  #|assert.eq("abc"[:], "abc")
  #|assert.eq("abc"[-4:], "abc")
  #|assert.eq("abc"[-3:], "abc")
  #|assert.eq("abc"[-2:], "bc")
  #|assert.eq("abc"[-1:], "c")
  #|assert.eq("abc"[0:], "abc")
  #|assert.eq("abc"[1:], "bc")
  #|assert.eq("abc"[2:], "c")
  #|assert.eq("abc"[3:], "")
  #|assert.eq("abc"[4:], "")
  #|assert.eq("abc"[:-4], "")
  #|assert.eq("abc"[:-3], "")
  #|assert.eq("abc"[:-2], "a")
  #|assert.eq("abc"[:-1], "ab")
  #|assert.eq("abc"[:0], "")
  #|assert.eq("abc"[:1], "a")
  #|assert.eq("abc"[:2], "ab")
  #|assert.eq("abc"[:3], "abc")
  #|assert.eq("abc"[:4], "abc")
  #|assert.eq("abc"[1:2], "b")
  #|assert.eq("abc"[2:1], "")
  #|
  #|# non-unit strides
  #|assert.eq("abcd"[0:4:1], "abcd")
  #|assert.eq("abcd"[::2], "ac")
  #|assert.eq("abcd"[1::2], "bd")
  #|assert.eq("abcd"[4:0:-1], "dcb")
  #|assert.eq("banana"[7::-2], "aaa")
  #|assert.eq("banana"[6::-2], "aaa")
  #|assert.eq("banana"[5::-2], "aaa")
  #|assert.eq("banana"[4::-2], "nnb")
  #|assert.eq("banana"[::-1], "ananab")
  #|assert.eq("banana"[None:None:-2], "aaa")
  #|assert.fails(lambda: "banana"[1.0::], "slice indices must be integers")
  #|assert.fails(lambda: "banana"[:"":], "slice indices must be integers")
  #|assert.fails(lambda: "banana"[:"":True], "slice step must be an integer")
  #|
  #|# in, not in
  #|assert.true("oo" in "food")
  #|assert.true("ox" not in "food")
  #|assert.true("" in "food")
  #|assert.true("" in "")
  #|assert.fails(lambda: 1 in "", "requires string as left operand")
  #|assert.fails(lambda: "" in 1, "unknown binary op")
  #|
  #|# ==, !=
  #|assert.eq("hello", "he" + "llo")
  #|assert.ne("hello", "Hello")
  #|
  #|# string % tuple formatting
  #|assert.eq("A" % (), "A")
  #|assert.eq("A %d %x Z" % (123, 456), "A 123 1c8 Z")
  #|assert.eq("%s %r" % ("hi", "hi"), 'hi "hi"')
  #|assert.eq("%%d %d" % 1, "%d 1")
  #|assert.fails(lambda: "%d %d" % 1, "not enough arguments for format string")
  #|assert.fails(lambda: "%d %d" % (1, 2, 3), "too many arguments for format string")
  #|assert.fails(lambda: "" % 1, "too many arguments for format string")
  #|
  #|# %c
  #|assert.eq("%c" % 65, "A")
  #|assert.eq("%c" % "A", "A")
  #|assert.fails(lambda: "%c" % "abc", "requires a single-character string")
  #|assert.fails(lambda: "%c" % "", "requires a single-character string")
  #|assert.fails(lambda: "%c" % -1, "requires a valid Unicode code point")
  #|
  #|# str.format
  #|assert.eq("a{}b".format(123), "a123b")
  #|assert.eq("a{}b{}c{}d{}".format(1, 2, 3, 4), "a1b2c3d4")
  #|assert.eq("a{{b".format(), "a{b")
  #|assert.eq("a}}b".format(), "a}b")
  #|assert.eq("a{{b}}c".format(), "a{b}c")
  #|assert.eq("a{x}b{y}c{}".format(1, x=2, y=3), "a2b3c1")
  #|assert.fails(lambda: "a{z}b".format(x=1), "keyword z not found")
  #|assert.fails(lambda: "{-1}".format(1), "not found")
  #|assert.fails(lambda: "{+0}".format(1), "not found")
  #|assert.eq("{0000000000001}".format(0, 1), "1")
  #|assert.eq("{012}".format(*range(100)), "12")
  #|assert.fails(lambda: "a{123}b".format(), "tuple index out of range")
  #|assert.fails(lambda: "a{}b{}c".format(1), "tuple index out of range")
  #|assert.eq("a{010}b".format(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10), "a10b")
  #|assert.fails(lambda: "a{}b{1}c".format(1, 2), "cannot switch from automatic field numbering to manual")
  #|assert.eq("a{!s}c".format("b"), "abc")
  #|assert.eq("a{!r}c".format("b"), "a\"b\"c")
  #|assert.eq("a{x!r}c".format(x="b"), "a\"b\"c")
  #|assert.fails(lambda: "{x!}".format(x=1), "unknown conversion")
  #|assert.fails(lambda: "{a.b}".format(1), "syntax x.y is not supported")
  #|assert.fails(lambda: "{a[0]}".format(1), "syntax a[i] is not supported")
  #|assert.fails(lambda: "{ {} }".format(1), "nested replacement fields not supported")
  #|assert.fails(lambda: "{{}".format(1), "single '}' in format")
  #|assert.fails(lambda: "{}}".format(1), "single '}' in format")
  #|assert.fails(lambda: "}}{".format(1), "unmatched '{' in format")
  #|assert.fails(lambda: "}{{".format(1), "single '}' in format")
  #|assert.fails(lambda: "{:>10}".format(1), "format spec features not supported")
  #|assert.fails(lambda: "{0:d}".format(1), "format spec features not supported")
  #|
  #|# str.split, str.rsplit
  #|assert.eq("a.b.c.d".split("."), ["a", "b", "c", "d"])
  #|assert.eq("a.b.c.d".rsplit("."), ["a", "b", "c", "d"])
  #|assert.eq("a.b.c.d".split(".", -1), ["a", "b", "c", "d"])
  #|assert.eq("a.b.c.d".rsplit(".", -1), ["a", "b", "c", "d"])
  #|assert.eq("a.b.c.d".split(".", 0), ["a.b.c.d"])
  #|assert.eq("a.b.c.d".rsplit(".", 0), ["a.b.c.d"])
  #|assert.eq("a.b.c.d".split(".", 1), ["a", "b.c.d"])
  #|assert.eq("a.b.c.d".rsplit(".", 1), ["a.b.c", "d"])
  #|assert.eq("a.b.c.d".split(".", 2), ["a", "b", "c.d"])
  #|assert.eq("a.b.c.d".rsplit(".", 2), ["a.b", "c", "d"])
  #|assert.eq("  ".split("."), ["  "])
  #|assert.eq("  ".rsplit("."), ["  "])
  #|
  #|# {,r}split on white space
  #|assert.eq(" a bc\n  def \t  ghi".split(), ["a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".split(None), ["a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".split(None, 0), ["a bc\n  def \t  ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".rsplit(None, 0), [" a bc\n  def \t  ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".split(None, 1), ["a", "bc\n  def \t  ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".rsplit(None, 1), [" a bc\n  def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".split(None, 2), ["a", "bc", "def \t  ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".rsplit(None, 2), [" a bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".split(None, 3), ["a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".rsplit(None, 3), [" a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".split(None, 4), ["a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".rsplit(None, 4), ["a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi".rsplit(None, 5), ["a", "bc", "def", "ghi"])
  #|assert.eq(" a bc\n  def \t  ghi ".split(None, 0), ["a bc\n  def \t  ghi "])
  #|assert.eq(" a bc\n  def \t  ghi ".rsplit(None, 0), [" a bc\n  def \t  ghi"])
  #|assert.eq(" a bc\n  def \t  ghi ".split(None, 1), ["a", "bc\n  def \t  ghi "])
  #|assert.eq(" a bc\n  def \t  ghi ".rsplit(None, 1), [" a bc\n  def", "ghi"])
  #|assert.eq("--aa--bb--cc--".split("-", 0), ["--aa--bb--cc--"])
  #|assert.eq("  aa  bb  cc  ".split(None, 0), ["aa  bb  cc  "])
  #|assert.eq("--aa--bb--cc--".rsplit("-", 0), ["--aa--bb--cc--"])
  #|assert.eq("  aa  bb  cc  ".rsplit(None, 0), ["  aa  bb  cc"])
  #|assert.eq("--aa--bb--cc--".split("-", 1), ["", "-aa--bb--cc--"])
  #|assert.eq("--aa--bb--cc--".rsplit("-", 1), ["--aa--bb--cc-", ""])
  #|assert.eq("  aa  bb  cc  ".split(None, 1), ["aa", "bb  cc  "])
  #|assert.eq("  aa  bb  cc  ".rsplit(None, 1), ["  aa  bb", "cc"])
  #|assert.eq("--aa--bb--cc--".split("-", -1), ["", "", "aa", "", "bb", "", "cc", "", ""])
  #|assert.eq("--aa--bb--cc--".rsplit("-", -1), ["", "", "aa", "", "bb", "", "cc", "", ""])
  #|assert.eq("  aa  bb  cc  ".split(None, -1), ["aa", "bb", "cc"])
  #|assert.eq("  aa  bb  cc  ".rsplit(None, -1), ["aa", "bb", "cc"])
  #|assert.eq("  ".split(None), [])
  #|assert.eq("  ".rsplit(None), [])
  #|assert.eq("localhost:80".rsplit(":", 1)[-1], "80")
  #|
  #|# str.splitlines
  #|assert.eq("\nabc\ndef".splitlines(), ["", "abc", "def"])
  #|assert.eq("\nabc\ndef".splitlines(True), ["\n", "abc\n", "def"])
  #|assert.eq("\nabc\ndef\n".splitlines(), ["", "abc", "def"])
  #|assert.eq("\nabc\ndef\n".splitlines(True), ["\n", "abc\n", "def\n"])
  #|assert.eq("".splitlines(), [])
  #|assert.eq("".splitlines(True), [])
  #|assert.eq("a".splitlines(), ["a"])
  #|assert.eq("a".splitlines(True), ["a"])
  #|assert.eq("\n".splitlines(), [""])
  #|assert.eq("\n".splitlines(True), ["\n"])
  #|assert.eq("a\n".splitlines(), ["a"])
  #|assert.eq("a\n".splitlines(True), ["a\n"])
  #|assert.eq("a\n\nb".splitlines(), ["a", "", "b"])
  #|assert.eq("a\n\nb".splitlines(True), ["a\n", "\n", "b"])
  #|assert.eq("a\nb\nc".splitlines(), ["a", "b", "c"])
  #|assert.eq("a\nb\nc".splitlines(True), ["a\n", "b\n", "c"])
  #|assert.eq("a\nb\nc\n".splitlines(), ["a", "b", "c"])
  #|assert.eq("a\nb\nc\n".splitlines(True), ["a\n", "b\n", "c\n"])
  #|
  #|# str.{,l,r}strip
  #|assert.eq(" \tfoo\n ".strip(), "foo")
  #|assert.eq(" \tfoo\n ".lstrip(), "foo\n ")
  #|assert.eq(" \tfoo\n ".rstrip(), " \tfoo")
  #|assert.eq(" \tfoo\n ".strip(""), "foo")
  #|assert.eq(" \tfoo\n ".lstrip(""), "foo\n ")
  #|assert.eq(" \tfoo\n ".rstrip(""), " \tfoo")
  #|assert.eq("blah.h".strip("b.h"), "la")
  #|assert.eq("blah.h".lstrip("b.h"), "lah.h")
  #|assert.eq("blah.h".rstrip("b.h"), "bla")
  #|
  #|# str.count
  #|assert.eq("banana".count("a"), 3)
  #|assert.eq("banana".count("a", 2), 2)
  #|assert.eq("banana".count("a", -4, -2), 1)
  #|assert.eq("banana".count("a", 1, 4), 2)
  #|assert.eq("banana".count("a", 0, -100), 0)
  #|
  #|# str.{starts,ends}with
  #|assert.true("foo".endswith("oo"))
  #|assert.true(not "foo".endswith("x"))
  #|assert.true("foo".startswith("fo"))
  #|assert.true(not "foo".startswith("x"))
  #|assert.fails(lambda: "foo".startswith(1), "got int")
  #|assert.true("abc".startswith(("a", "A")))
  #|assert.true("ABC".startswith(("a", "A")))
  #|assert.true(not "ABC".startswith(("b", "B")))
  #|assert.fails(lambda: "123".startswith((1, 2)), "got int")
  #|assert.fails(lambda: "123".startswith(["3"]), "got list")
  #|assert.true("abc".endswith(("c", "C")))
  #|assert.true("ABC".endswith(("c", "C")))
  #|assert.true(not "ABC".endswith(("b", "B")))
  #|assert.fails(lambda: "123".endswith((1, 2)), "got int")
  #|assert.fails(lambda: "123".endswith(["3"]), "got list")
  #|
  #|# start/end args
  #|assert.true("abc".startswith("bc", 1))
  #|assert.true(not "abc".startswith("b", 999))
  #|assert.true("abc".endswith("ab", None, -1))
  #|assert.true(not "abc".endswith("b", None, -999))
  #|
  #|# str.replace
  #|assert.eq("banana".replace("a", "o", 1), "bonana")
  #|assert.eq("banana".replace("a", "o"), "bonono")
  #|
  #|# str.{,r}find
  #|assert.eq("foofoo".find("oo"), 1)
  #|assert.eq("foofoo".find("ox"), -1)
  #|assert.eq("foofoo".find("oo", 2), 4)
  #|assert.eq("foofoo".rfind("oo"), 4)
  #|assert.eq("foofoo".rfind("ox"), -1)
  #|assert.eq("foofoo".rfind("oo", 1, 4), 1)
  #|assert.eq("foofoo".find(""), 0)
  #|assert.eq("foofoo".rfind(""), 6)
  #|
  #|# str.{,r}partition
  #|assert.eq("foo/bar/wiz".partition("/"), ("foo", "/", "bar/wiz"))
  #|assert.eq("foo/bar/wiz".rpartition("/"), ("foo/bar", "/", "wiz"))
  #|assert.eq("foo/bar/wiz".partition("."), ("foo/bar/wiz", "", ""))
  #|assert.eq("foo/bar/wiz".rpartition("."), ("", "", "foo/bar/wiz"))
  #|assert.fails(lambda: "foo/bar/wiz".partition(""), "empty separator")
  #|assert.fails(lambda: "foo/bar/wiz".rpartition(""), "empty separator")
  #|assert.eq("?".join(["foo", "a/b/c.go".rpartition("/")[0]]), "foo?a/b")
  #|
  #|# str.is{alpha,...}
  #|def test_predicates():
  #|    predicates = ["alnum", "alpha", "digit", "lower", "space", "title", "upper"]
  #|    table = {
  #|        "Hello, World!": "title",
  #|        "hello, world!": "lower",
  #|        "base64": "alnum lower",
  #|        "HAL-9000": "upper",
  #|        "Catch-22": "title",
  #|        "": "",
  #|        "\n\t\r": "space",
  #|        "abc": "alnum alpha lower",
  #|        "ABC": "alnum alpha upper",
  #|        "123": "alnum digit",
  #|    }
  #|    for str, want in table.items():
  #|        got = " ".join([name for name in predicates if getattr(str, "is"+name)()])
  #|        if got != want:
  #|            assert.fail("%r matched [%s], want [%s]" % (str, got, want))
  #|
  #|test_predicates()
  #|
  #|# Strings are not iterable
  #|assert.eq(len("abc"), 3)
  #|assert.true("a" in "abc")
  #|assert.eq("abc"[1], "b")
  #|
  #|def for_string():
  #|    for x in "abc":
  #|        pass
  #|
  #|def args(*args2): return args2
  #|
  #|assert.fails(lambda: args(*"abc"), "must be iterable, not string")
  #|assert.fails(lambda: list("abc"), "got string, want iterable")
  #|assert.fails(lambda: tuple("abc"), "got string, want iterable")
  #|assert.fails(lambda: enumerate("ab"), "got string, want iterable")
  #|assert.fails(lambda: sorted("abc"), "got string, want iterable")
  #|assert.fails(lambda: [].extend("bc"), "got string, want iterable")
  #|assert.fails(lambda: ",".join("abc"), "got string, want iterable")
  #|assert.fails(for_string, "not iterable")
  #|assert.fails(lambda: [x for x in "abc"], "not iterable")
  #|assert.fails(lambda: all("abc"), "got string, want iterable")
  #|assert.fails(lambda: any("abc"), "got string, want iterable")
  #|assert.fails(lambda: reversed("abc"), "got string, want iterable")
  #|
  #|# str.join
  #|assert.eq(",".join([]), "")
  #|assert.eq(",".join(["a"]), "a")
  #|assert.eq(",".join(["a", "b"]), "a,b")
  #|assert.eq(",".join(["a", "b", "c"]), "a,b,c")
  #|assert.eq(",".join(("a", "b", "c")), "a,b,c")
  #|assert.eq("".join(("a", "b", "c")), "abc")
  #|assert.fails(lambda: "".join(None), "got NoneType, want iterable")
  #|assert.fails(lambda: "".join(["one", 2]), "join: in list, want string, got int")
  #|
  #|# str.capitalize
  #|assert.eq("hElLo, WoRlD!".capitalize(), "Hello, world!")
  #|
  #|# str.lower
  #|assert.eq("hElLo, WoRlD!".lower(), "hello, world!")
  #|
  #|# str.upper
  #|assert.eq("hElLo, WoRlD!".upper(), "HELLO, WORLD!")
  #|
  #|# str.title
  #|assert.eq("hElLo, WoRlD!".title(), "Hello, World!")
  #|
  #|# removesuffix
  #|assert.eq("Apricot".removesuffix("cot"), "Apri")
  #|assert.eq("Apricot".removesuffix("Cot"), "Apricot")
  #|assert.eq("Apricot".removesuffix("t"), "Aprico")
  #|assert.eq("a".removesuffix(""), "a")
  #|assert.eq("".removesuffix(""), "")
  #|assert.eq("".removesuffix("a"), "")
  #|assert.eq("Apricot".removesuffix("co"), "Apricot")
  #|assert.eq("Apricotcot".removesuffix("cot"), "Apricot")
  #|
  #|# removeprefix
  #|assert.eq("Apricot".removeprefix("Apr"), "icot")
  #|assert.eq("Apricot".removeprefix("apr"), "Apricot")
  #|assert.eq("Apricot".removeprefix("A"), "pricot")
  #|assert.eq("a".removeprefix(""), "a")
  #|assert.eq("".removeprefix(""), "")
  #|assert.eq("".removeprefix("a"), "")
  #|assert.eq("Apricot".removeprefix("pr"), "Apricot")

///|
test "string.star: all assertions pass" {
  let errs = run_star_string(string_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
