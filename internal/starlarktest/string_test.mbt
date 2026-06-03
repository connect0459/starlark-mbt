// Integration tests derived from string.star.
// Regex patterns in assert.fails are simplified to plain substrings.
// Unicode-specific multi-byte byte-index tests are excluded.

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
  #|assert.fails(lambda: 1.0 * "abc", "unknown binary op: float * string")
  #|
  #|# len (ASCII only)
  #|assert.eq(len("Hello"), 5)
  #|assert.eq(len(""), 0)
  #|
  #|# chr & ord
  #|assert.eq(chr(65), "A")
  #|assert.eq(chr(97), "a")
  #|assert.fails(lambda: chr(-1), "out of range.*<0")
  #|assert.fails(lambda: chr(0x110000), "out of range.*>0x10FFFF")
  #|assert.eq(ord("A"), 0x41)
  #|assert.fails(lambda: ord("abc"), "string encodes 3 Unicode code points, want 1")
  #|assert.fails(lambda: ord(""), "string encodes 0 Unicode code points, want 1")
  #|
  #|# codepoint_ords returns string.codepoints iterable
  #|assert.eq(list("abc".codepoint_ords()), [97, 98, 99])
  #|assert.eq(list("".codepoint_ords()), [])
  #|
  #|# codepoints returns string.codepoints iterable
  #|assert.eq(list("abc".codepoints()), ["a", "b", "c"])
  #|assert.eq(list("".codepoints()), [])
  #|
  #|# elem_ords returns string.elems iterable of byte values
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
  #|assert.fails(lambda: "banana"[1.0::], "invalid start index: got float, want int")
  #|assert.fails(lambda: "banana"[:"":], "invalid end index: got string, want int")
  #|assert.fails(lambda: "banana"[:"":True], "invalid slice step: got bool, want int")
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
  #|# dict-keyed % format
  #|assert.eq("A" % {'unused': 123}, "A")
  #|assert.eq("A %(foo)d %(bar)s Z" % {"foo": 123, "bar": "hi"}, "A 123 hi Z")
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
  #|assert.fails(lambda: "{:>10}".format(1), "format spec features not supported in replacement fields: >10")
  #|assert.fails(lambda: "{0:d}".format(1), "format spec features not supported in replacement fields: d")
  #|assert.eq("{x:}".format(x=1), "1")
  #|assert.eq("{0:}".format(1), "1")
  #|assert.eq("{:}".format(1), "1")
  #|assert.fails(lambda: "{0:5}".format(1), "format spec features not supported in replacement fields: 5")
  #|assert.fails(lambda: "{x!s:>3}".format(x=1), "format spec features not supported in replacement fields: >3")
  #|# str.format edge cases (string.star lines 206-215)
  #|assert.fails(lambda: "{-0}".format(1), "keyword -0 not found")
  #|assert.fails(lambda: "{0,1} and {1}".format(1, 2), "keyword 0,1 not found")
  #|assert.fails(lambda: "{x!:}".format(x = 1), "unknown conversion")
  #|assert.fails(lambda: "a{}b{1}c".format(1, 2), "cannot switch from automatic")
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
  #|# carriage return is an ordinary character, not a line break
  #|assert.eq("a\rb".splitlines(), ["a\rb"])
  #|assert.eq("a\r\nb".splitlines(), ["a\r", "b"])
  #|assert.eq("a\r\nb".splitlines(True), ["a\r\n", "b"])
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
let string_hash_parity_src : String =
  #|load("assert.star", "assert")
  #|# hash must follow java.lang.String.hashCode
  #|wanthash = {
  #|    "": 0,
  #|    "\0" * 100: 0,
  #|    "hello": 99162322,
  #|    "world": 113318802,
  #|    "Hello, 世界!": 417292677,
  #|}
  #|gothash = {s: hash(s) for s in wanthash}
  #|assert.eq(gothash, wanthash)

///|
test "string hash follows java.lang.String.hashCode" {
  let errs = run_star_string(string_hash_parity_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string.star: all assertions pass" {
  let errs = run_star_string(string_star_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_not_iterable_src : String =
  #|load("assert.star", "assert")
  #|def for_string():
  #|  for x in "abc":
  #|    pass
  #|assert.fails(lambda: enumerate("ab"), "got string, want iterable")
  #|assert.fails(lambda: sorted("abc"), "got string, want iterable")
  #|assert.fails(lambda: zip("ab", "cd"), "not iterable: string")
  #|assert.fails(lambda: dict(["ab"]), "not iterable")
  #|assert.fails(for_string, "string value is not iterable")
  #|assert.fails(lambda: [x for x in "abc"], "string value is not iterable")
  #|assert.fails(lambda: set("abc"), "got string, want iterable")
  #|assert.fails(lambda: set() | "abc", "unknown binary op: set | string")

///|
test "strings are not iterable (string.star lines 424-430)" {
  let errs = run_star_string(string_not_iterable_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "str.elems returns string.elems type with len and index support" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.eq(type("abc".elems()), "string.elems")
      #|assert.eq(type("abc".elem_ords()), "string.elems")
      #|assert.eq(len("abc".elems()), 3)
      #|assert.eq("abc".elems()[1], "b")
      #|assert.eq(list("abc".elems()), ["a", "b", "c"])
      #|assert.eq(list("abc".elem_ords()), [97, 98, 99])
      #|assert.eq(str("abc".elems()), '"abc".elems()')
      #|assert.eq("abc".elem_ords()[2], 99)
      #|assert.eq("abc".elem_ords()[0], 97)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "str.codepoints returns string.codepoints type" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|assert.eq(type("abc".codepoints()), "string.codepoints")
      #|assert.eq(type("abc".codepoint_ords()), "string.codepoints")
      #|assert.eq(list("abc".codepoints()), ["a", "b", "c"])
      #|assert.eq(list("abc".codepoint_ords()), [97, 98, 99])
      #|assert.eq(str("abc".codepoints()), '"abc".codepoints()')
      #|assert.fails(lambda: len("abc".codepoints()), "no len")
      #|assert.fails(lambda: "abc".codepoints()[0], "unhandled index")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "bytes.elems returns bytes.elems type" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|hello = bytes("hello")
      #|assert.eq(type(hello.elems()), "bytes.elems")
      #|assert.eq(list(hello.elems()), [104, 101, 108, 108, 111])
      #|assert.eq(bytes(hello.elems()), hello)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string iterators work correctly for multi-byte Unicode strings" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|s = "abcЙ😿"
      #|# codepoint_ords: type and contents
      #|assert.eq(type(s.codepoint_ords()), "string.codepoints")
      #|assert.eq(str(s.codepoint_ords()), '"abcЙ😿".codepoint_ords()')
      #|assert.eq(list(s.codepoint_ords()), [97, 98, 99, 1049, 128575])
      #|assert.fails(lambda: len(s.codepoint_ords()), "no len")
      #|assert.fails(lambda: s.codepoint_ords()[2], "unhandled index")
      #|# codepoints: type and contents
      #|assert.eq(type(s.codepoints()), "string.codepoints")
      #|assert.eq(str(s.codepoints()), '"abcЙ😿".codepoints()')
      #|assert.eq(list(s.codepoints()), ["a", "b", "c", "Й", "😿"])
      #|# elem_ords: type, contents, indexing, length
      #|assert.eq(type(s.elem_ords()), "string.elems")
      #|assert.eq(str(s.elem_ords()), '"abcЙ😿".elem_ords()')
      #|assert.eq(list(s.elem_ords()), [97, 98, 99, 208, 153, 240, 159, 152, 191])
      #|assert.eq(s.elem_ords()[2], 99)
      #|assert.eq(len(s.elem_ords()), 9)
      #|# elems: type, contents, indexing, length, repr of non-ASCII bytes
      #|assert.eq(type(s.elems()), "string.elems")
      #|assert.eq(str(s.elems()), '"abcЙ😿".elems()')
      #|assert.eq(s.elems()[2], "c")
      #|assert.eq(len(s.elems()), 9)
      #|assert.eq(repr(list(s.elems())), r'["a", "b", "c", "\xd0", "\x99", "\xf0", "\x9f", "\x98", "\xbf"]')
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string operations on partial UTF-8 bytes" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|# ord of a single continuation byte returns U+FFFD
      #|assert.eq(ord("Й"[1:]), 0xFFFD)
      #|# ord of 3 continuation bytes fails with right message
      #|assert.fails(lambda: ord("😿"[1:]), "string encodes 3 Unicode code points, want 1")
      #|# repr of first byte of a 3-byte sequence (0xe4)
      #|assert.eq(repr("Hello, 世界!"[7]), '"\\xe4"')
      #|assert.eq(list(("A" + "😿Z"[1:]).codepoint_ords()), [65, 0xFFFD, 0xFFFD, 0xFFFD, 90])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string concat preserves raw bytes from invalid UTF-8 sequences" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|# "😿Z"[1:] has bytes [0x9f, 0x98, 0xbf, 0x5a] (4 bytes)
      #|# "A" + that should yield 5 bytes, not 11
      #|assert.eq(len("A" + "😿Z"[1:]), 5)
      #|assert.eq(list(("A" + "😿Z"[1:]).elem_ords()), [65, 159, 152, 191, 90])
      #|assert.eq(
      #|    repr(list(("A" + "😿Z"[1:]).elems())),
      #|    '["A", "\\x9f", "\\x98", "\\xbf", "Z"]',
      #|)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string repeat preserves raw bytes from invalid UTF-8 sequences" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|# "😿Z"[1:] has 4 bytes; repeating twice should yield 8 bytes
      #|assert.eq(len("😿Z"[1:] * 2), 8)
      #|assert.eq(list(("😿Z"[1:] * 2).elem_ords()), [159, 152, 191, 90, 159, 152, 191, 90])
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_method_spellcheck_src : String =
  #|load("assert.star", "assert")
  #|# method spell check (string.star lines 471-473)
  #|assert.fails(lambda: "".starts_with, "no .starts_with field.*did you mean .startswith")
  #|assert.fails(lambda: "".StartsWith, "no .StartsWith field.*did you mean .startswith")
  #|assert.fails(lambda: "".fin, "no .fin field.*did you mean .find")

///|
test "string.star: method spell-check for unknown attributes" {
  let errs = run_star_string(string_method_spellcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_percent_c_unicode_src : String =
  #|load("assert.star", "assert")
  #|# %c with non-ASCII int (string.star lines 187, 189)
  #|assert.eq("%c" % 0x3b1, "α")
  #|assert.eq("%c" % "α", "α")

///|
test "string.star: %c format with non-ASCII Unicode" {
  let errs = run_star_string(string_percent_c_unicode_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_percent_c_astral_src : String =
  #|load("assert.star", "assert")
  #|assert.eq("%c" % 0x1D11E, "𝄞")
  #|assert.eq("%c" % "𝄞", "𝄞")
  #|# multi-char strings must still fail
  #|assert.fails(lambda: "%c" % "ab", "requires a single-character string")

///|
test "string.star: %c with astral codepoint is accepted" {
  let errs = run_star_string(string_percent_c_astral_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_repeat_overflow_src : String =
  #|load("assert.star", "assert")
  #|# string * large_int raises (string.star line 27)
  #|assert.fails(lambda: "abc" * (1000000 * 1000000), "repeat count 1000000000000 too large")

///|
test "string.star: string * huge_int raises repeat-count-too-large" {
  let errs = run_star_string(string_repeat_overflow_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_byte_offset_src : String =
  #|load("assert.star", "assert")
  #|s = "abcЙ😿"
  #|# find/index return byte offsets
  #|assert.eq(s.find("😿"), 5)
  #|assert.eq(s.find("Й"), 3)
  #|assert.eq(s.find("c"), 2)
  #|assert.eq(s.index("😿"), 5)
  #|assert.eq(s.rfind("c"), 2)
  #|assert.eq(s.rindex("Й"), 3)
  #|# count over bytes
  #|assert.eq(s.count("c"), 1)
  #|assert.eq(s.count("😿"), 1)
  #|# start/end arguments are byte offsets
  #|assert.eq(s.find("c", 3), -1)
  #|assert.eq(s.find("😿", 5), 5)
  #|# partition splits on byte boundaries
  #|assert.eq(s.partition("Й"), ("abc", "Й", "😿"))
  #|assert.eq(s.rpartition("Й"), ("abc", "Й", "😿"))
  #|# startswith/endswith with byte-offset slice form
  #|assert.true(s.startswith("abc"))
  #|assert.true(s.endswith("😿"))
  #|assert.true(s.endswith("Й", 0, 5))
  #|assert.true(not s.endswith("Й", 0, 4))

///|
test "string search methods use UTF-8 byte offsets" {
  let errs = run_star_string(string_byte_offset_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_strip_argcheck_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "x".strip(1), "strip: for parameter 1: got int, want string")
  #|assert.fails(lambda: "x".lstrip([]), "lstrip: for parameter 1: got list, want string")
  #|assert.fails(lambda: "x".rstrip(None), "rstrip: for parameter 1: got NoneType, want string")
  #|assert.fails(lambda: "x".strip("a", "b"), "strip: got 2 arguments, want at most 1")
  #|assert.fails(lambda: "x".strip(chars="a"), "strip: unexpected keyword arguments")
  #|# valid usage still works
  #|assert.eq("  hi  ".strip(), "hi")
  #|assert.eq("xxhixx".strip("x"), "hi")

///|
test "str.strip rejects non-string and excess args" {
  let errs = run_star_string(string_strip_argcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_replace_argcheck_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "banana".replace("a", "o", "bad"), "replace: for parameter 3: got string, want int")
  #|assert.fails(lambda: "banana".replace("a"), "replace: got 1 arguments, want at least 2")
  #|assert.fails(lambda: "banana".replace("a", "o", 1, 9), "replace: got 4 arguments, want at most 3")
  #|# valid usage still works
  #|assert.eq("banana".replace("a", "o"), "bonono")
  #|assert.eq("banana".replace("a", "o", 2), "bonona")

///|
test "str.replace rejects non-int count and excess args" {
  let errs = run_star_string(string_replace_argcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_search_argcheck_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "x".find("y", 0, 1, 99), "find: got 4 arguments, want at most 3")
  #|assert.fails(lambda: "x".count("y", 0, 1, 99), "count: got 4 arguments, want at most 3")
  #|assert.fails(lambda: "x".rfind("y", 0, 1, 99), "rfind: got 4 arguments, want at most 3")
  #|assert.fails(lambda: "x".find("y", start=0), "find: unexpected keyword arguments")
  #|assert.fails(lambda: "abc".startswith("a", 0, 1, 9), "startswith: got 4 arguments, want at most 3")
  #|assert.fails(lambda: "abc".endswith("c", 0, 1, 9), "endswith: got 4 arguments, want at most 3")
  #|# valid usage still works
  #|assert.eq("foofoo".find("oo", 2), 4)
  #|assert.eq("banana".count("a", 2), 2)

///|
test "str search methods reject excess positional/keyword args" {
  let errs = run_star_string(string_search_argcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_split_argcheck_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "a b".split(sep=" "), "split: unexpected keyword arguments")
  #|assert.fails(lambda: "a b".rsplit(maxsplit=1), "rsplit: unexpected keyword arguments")
  #|assert.fails(lambda: "a b".split(1), "split: got int for separator, want string")
  #|assert.fails(lambda: "a b".split(" ", "x"), "split: for parameter 2: got string, want int")
  #|assert.fails(lambda: "a b".split(" ", 1, 9), "split: got 3 arguments, want at most 2")
  #|# valid usage still works
  #|assert.eq("a b c".split(" "), ["a", "b", "c"])
  #|assert.eq("a b c".split(" ", 1), ["a", "b c"])
  #|assert.eq("a b c".rsplit(" ", 1), ["a b", "c"])

///|
test "str.split/rsplit reject keyword args" {
  let errs = run_star_string(string_split_argcheck_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_search_index_type_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "banana".find("a", 1.0), "find: invalid start index: got float, want int")
  #|assert.fails(lambda: "banana".find("a", 0, []), "find: invalid end index: got list, want int")
  #|assert.fails(lambda: "banana".count("a", "bad"), "count: invalid start index: got string, want int")
  #|assert.fails(lambda: "banana".rfind("a", 1.0), "rfind: invalid start index: got float, want int")
  #|assert.fails(lambda: "banana".rindex("a", 0, True), "rindex: invalid end index: got bool, want int")
  #|assert.fails(lambda: "banana".index("a", 1.0), "index: invalid start index: got float, want int")
  #|assert.fails(lambda: "hello".startswith("h", 1.0), "startswith: invalid start index: got float, want int")
  #|assert.fails(lambda: "hello".endswith("o", 0, "x"), "endswith: invalid end index: got string, want int")
  #|# None is accepted as a default (no error)
  #|assert.eq("banana".find("a", None), 1)
  #|assert.eq("banana".find("a", None, None), 1)
  #|# valid int args still work
  #|assert.eq("banana".find("a", 2), 3)
  #|assert.eq("banana".count("a", 2, 6), 2)

///|
test "str search methods reject non-int start/end args" {
  let errs = run_star_string(string_search_index_type_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_rindex_argtype_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "abc".rindex(1), "rindex: for parameter 1: got int, want string")
  #|assert.fails(lambda: "abc".index(1), "index: for parameter 1: got int, want string")
  #|assert.fails(lambda: "abc".find(1), "find: for parameter 1: got int, want string")
  #|assert.fails(lambda: "abc".rfind(1), "rfind: for parameter 1: got int, want string")
  #|assert.fails(lambda: "abc".count(1), "count: for parameter 1: got int, want string")

///|
test "str.rindex/index/find/rfind/count first-arg type error uses method prefix" {
  let errs = run_star_string(string_rindex_argtype_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_unicode_case_src : String =
  #|load("assert.star", "assert")
  #|# str.capitalize with non-ASCII
  #|assert.eq("por qué".capitalize(), "Por qué")
  #|assert.eq("¿Por qué?".capitalize(), "¿por qué?")
  #|# str.islower with Unicode digraphs
  #|assert.true("ǆenan ǉubović".islower())
  #|# str.isupper with Unicode digraphs
  #|assert.true("ǄENAN ǇUBOVIĆ".isupper())
  #|# str.title with non-ASCII
  #|assert.eq("por qué".title(), "Por Qué")
  #|assert.eq("¿Por qué?".title(), "¿Por Qué?")
  #|assert.eq("ǉubović".title(), "ǈubović")
  #|# str.istitle with Unicode digraphs
  #|assert.true("ǅenan ǈubović".istitle())
  #|assert.true(not "Ǆenan Ǉubović".istitle())

///|
test "str Unicode case methods (capitalize/islower/isupper/title/istitle)" {
  let errs = run_star_string(string_unicode_case_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_partition_argerr_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "abc".partition(1), "partition: for parameter 1: got int, want string")
  #|assert.fails(lambda: "abc".partition(), "partition: got 0 arguments, want 1")
  #|assert.fails(lambda: "abc".partition("a", "b"), "partition: got 2 arguments, want 1")
  #|assert.fails(lambda: "abc".rpartition(1), "rpartition: for parameter 1: got int, want string")
  #|assert.fails(lambda: "abc".rpartition(), "rpartition: got 0 arguments, want 1")
  #|assert.fails(lambda: "abc".rpartition("a", "b"), "rpartition: got 2 arguments, want 1")

///|
test "str.partition/rpartition arity and type errors use nameErr style" {
  let errs = run_star_string(string_partition_argerr_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_join_argerr_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: ",".join(), "join: got 0 arguments, want 1")
  #|assert.fails(lambda: ",".join([1], [2]), "join: got 2 arguments, want 1")
  #|assert.fails(lambda: ",".join(5), "join: for parameter 1: got int, want iterable")
  #|# element-type error already carries the prefix
  #|assert.fails(lambda: ",".join([1]), "join: in list, want string, got int")

///|
test "str.join arity and non-iterable errors use nameErr style" {
  let errs = run_star_string(string_join_argerr_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_format_msg_src : String =
  #|load("assert.star", "assert")
  #|assert.fails(lambda: "{0!q}".format(1), 'format: unknown conversion "q"')
  #|assert.fails(lambda: "{".format(), "format: unmatched '{' in format")
  #|assert.fails(lambda: "{a.b}".format(), "format: attribute syntax x.y is not supported in replacement fields: a.b")
  #|assert.fails(lambda: "{a[0]}".format(), "format: element syntax a[i] is not supported in replacement fields: a[0]")
  #|assert.fails(lambda: "{a{b}".format(), "format: nested replacement fields not supported")
  #|# an all-digit field name overflowing int range is a keyword, not an index
  #|assert.fails(lambda: "{99999999999999999999}".format(1), "format: keyword 99999999999999999999 not found")

///|
test "str.format reports descriptive error messages" {
  let errs = run_star_string(string_format_msg_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_unicode_case_mapping_src : String =
  #|load("assert.star", "assert")
  #|# upper/lower apply full Unicode simple case mapping (matching starlark-go)
  #|assert.eq("café".upper(), "CAFÉ")
  #|assert.eq("CAFÉ".lower(), "café")
  #|assert.eq("αβγ".upper(), "ΑΒΓ")
  #|assert.eq("ΑΒΓ".lower(), "αβγ")
  #|assert.eq("İ".lower(), "i")
  #|assert.eq("ß".upper(), "ß")
  #|assert.eq("ǆ".upper(), "Ǆ")
  #|assert.eq("Ǆ".lower(), "ǆ")
  #|# title uses titlecase for the first letter of each run of cased letters
  #|assert.eq("café".title(), "Café")
  #|assert.eq("αβγ".title(), "Αβγ")
  #|assert.eq("hello wörld".title(), "Hello Wörld")
  #|assert.eq("ǆ".title(), "ǅ")
  #|assert.eq("ǆ ǆ".title(), "ǅ ǅ")
  #|# capitalize titlecases the first letter, lowercases the rest
  #|assert.eq("café".capitalize(), "Café")
  #|assert.eq("ΑΒΓ".capitalize(), "Αβγ")
  #|assert.eq("ǆ ǆ".capitalize(), "ǅ ǆ")

///|
test "string upper/lower/title/capitalize apply Unicode case mapping" {
  let errs = run_star_string(string_unicode_case_mapping_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_islower_isupper_unicode_src : String =
  #|load("assert.star", "assert")
  #|# islower/isupper apply full Unicode case detection (matching starlark-go)
  #|assert.true("é".islower())
  #|assert.true(not "é".isupper())
  #|assert.true("É".isupper())
  #|assert.true(not "É".islower())
  #|assert.true("αβγ".islower())
  #|assert.true("ΑΒΓ".isupper())
  #|assert.true(not "αβγ".isupper())
  #|# ß is cased and equals both its simple upper and lower forms
  #|assert.true("ß".islower())
  #|assert.true("ß".isupper())
  #|# dotted/dotless I are not in any case-fold orbit, so they are uncased
  #|assert.true(not "ı".islower())
  #|assert.true(not "İ".islower())

///|
test "str.islower/isupper detect non-ASCII cased letters" {
  let errs = run_star_string(string_islower_isupper_unicode_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let string_istitle_unicode_src : String =
  #|load("assert.star", "assert")
  #|# istitle uses Unicode letter categories, matching starlark-go: an ASCII A-Z
  #|# or titlecase (Lt) letter leads a word; any other uppercase (Lu) letter, even
  #|# non-ASCII, disqualifies the whole string; lowercase (Ll) must follow a cased
  #|# letter.
  #|assert.true("Café Lait".istitle())
  #|assert.true("Hello World".istitle())
  #|assert.true("Hello Wörld".istitle())
  #|assert.true("Wörld Café".istitle())
  #|assert.true(not "Hello world".istitle())
  #|# a non-ASCII uppercase (Lu) letter disqualifies the string
  #|assert.true(not "Été".istitle())
  #|assert.true(not "Greek: Αβγ".istitle())
  #|assert.true(not "ΑβγΔ".istitle())
  #|# titlecase (Lt) digraph leads; uppercase (Lu) digraph disqualifies
  #|assert.true("ǅenan ǈubović".istitle())
  #|assert.true(not "Ǆenan Ǉubović".istitle())
  #|assert.true(not "Ǆ".istitle())
  #|assert.true("ǅ".istitle())
  #|# Roman numeral I has a case mapping but is category Nl, not a cased letter
  #|assert.true(not "Ⅰ".istitle())

///|
test "str.istitle uses Unicode letter categories" {
  let errs = run_star_string(string_istitle_unicode_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
let builtin_iterable_argerr_src : String =
  #|load("assert.star", "assert")
  #|# builtins taking an iterable report the starlark-go UnpackPositionalArgs prefix
  #|assert.fails(lambda: list("abc"), "list: for parameter 1: got string, want iterable")
  #|assert.fails(lambda: tuple("ab"), "tuple: for parameter 1: got string, want iterable")
  #|assert.fails(lambda: reversed("abc"), "reversed: for parameter 1: got string, want iterable")
  #|assert.fails(lambda: enumerate("ab"), "enumerate: for parameter 1: got string, want iterable")
  #|assert.fails(lambda: any("ab"), "any: for parameter 1: got string, want iterable")
  #|assert.fails(lambda: all("ab"), "all: for parameter 1: got string, want iterable")
  #|assert.fails(lambda: set("ab"), "set: for parameter 1: got string, want iterable")
  #|def ext(): [].extend("ab")
  #|assert.fails(ext, "extend: for parameter 1: got string, want iterable")

///|
test "iterable-argument builtins use the for-parameter-1 error prefix" {
  let errs = run_star_string(builtin_iterable_argerr_src)
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string.find: large BigInt start clamps to len not wraps" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|# 2^31 fits int64 but overflows int32; should clamp to len=5 → not found
      #|assert.eq("hello".find("h", 2147483648), -1)
      #|assert.eq("hello".count("h", 2147483648), 0)
      #|assert.eq("hello".rfind("h", 0, 2147483648), 0)
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}

///|
test "string.find: BigInt exceeding int64 raises out-of-range error" {
  let errs = run_star_string(
    (
      #|load("assert.star", "assert")
      #|# 2^63 exceeds int64 range
      #|assert.fails(lambda: "hello".find("h", 9223372036854775808), "find: invalid start index: 9223372036854775808 out of range")
    ),
  )
  if errs.length() != 0 {
    fail(errs.join("\n"))
  }
}
