// Tests for built-in functions and type methods called via exec_file.

///|
fn exec_b(src : String) -> Result[Module, @errors.EvalError] {
  let t = Thread::new("test")
  exec_file(t, "<test>", src, Options::default())
}

///|
fn g(m : Module, name : String) -> @value.Value? {
  m.get(name)
}

///|
// Run `src` and return the raw error message, or "<ok>" if it succeeded.
fn emsg(src : String) -> String {
  match exec_b(src) {
    Ok(_) => "<ok>"
    Err(e) => e.msg()
  }
}

// --- range ---

///|
test "exec_file: range(stop) produces correct sequence when iterated" {
  match exec_b("r = list(range(5))") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 5)
          assert_true(l[0] == @value.Value::Int(0N))
          assert_true(l[4] == @value.Value::Int(4N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: range(start, stop) begins at start" {
  match exec_b("r = list(range(2, 5))") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[0] == @value.Value::Int(2N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: range with step of zero raises error" {
  assert_true(exec_b("range(0, 10, 0)") is Err(_))
}

///|
test "exec_file: len of range exceeding Int32 max is computed without truncation" {
  match exec_b("n = len(range(0, 1 << 32))") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(4294967296N)))
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "exec_file: bool of large range is true" {
  match exec_b("b = bool(range(0, 1 << 32))") {
    Ok(m) => assert_true(g(m, "b") == Some(@value.Value::Bool(true)))
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
test "exec_file: large range is not equal to empty range" {
  match exec_b("eq = (range(0, 1 << 32) == range(0))") {
    Ok(m) => assert_true(g(m, "eq") == Some(@value.Value::Bool(false)))
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

// --- len ---

///|
test "exec_file: len returns element count of list" {
  match exec_b("n = len([1, 2, 3])") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: len returns byte count of string" {
  match exec_b("n = len(\"hello\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(5N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: len on non-sized type raises error" {
  assert_true(exec_b("len(42)") is Err(_))
}

// --- str, repr, type ---

///|
test "exec_file: str converts integer to decimal string" {
  match exec_b("s = str(42)") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "42")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: repr produces quoted string representation" {
  match exec_b("s = repr(\"hi\")") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "\"hi\"")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: type returns type name as string" {
  match exec_b("t = type(42)") {
    Ok(m) =>
      match g(m, "t") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "int")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- bool, int, float, abs ---

///|
test "exec_file: bool converts truthy value to True" {
  match exec_b("b = bool(1)") {
    Ok(m) => assert_true(g(m, "b") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: bool() with no argument returns False" {
  match exec_b("b = bool()") {
    Ok(m) => assert_true(g(m, "b") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int converts float to integer by truncation" {
  match exec_b("n = int(3.9)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int parses decimal string" {
  match exec_b("n = int(\"42\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(42N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int parses hex string with explicit base keyword" {
  match exec_b("n = int(\"ff\", base=16)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(255N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int rejects a non-int base for a string argument" {
  match exec_b("n = int(\"10\", \"x\")") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(e.msg().contains("int: for base, got string, want int"))
  }
}

///|
test "exec_file: int rejects an explicit base for a non-string argument" {
  match exec_b("n = int(5, base=\"x\")") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("int: can't convert non-string with explicit base"),
      )
  }
}

///|
test "exec_file: int error messages carry the int: name prefix" {
  match exec_b("int()") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("int: missing argument for x"))
  }
  match exec_b("int(float(\"nan\"))") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(e.msg().contains("int: cannot convert float NaN to integer"))
  }
  match exec_b("int(float(\"inf\"))") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("int: cannot convert float infinity to integer"),
      )
  }
}

///|
test "exec_file: int converts Bool to integer without TypeError" {
  match exec_b("a = int(True)\nb = int(False)") {
    Ok(m) => {
      assert_true(g(m, "a") == Some(@value.Value::Int(1N)))
      assert_true(g(m, "b") == Some(@value.Value::Int(0N)))
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: function call with too few arguments raises error" {
  assert_true(exec_b("def f(a, b): return a + b\nf(1)") is Err(_))
}

///|
test "exec_file: function call with too many arguments raises error" {
  assert_true(exec_b("def f(a): return a\nf(1, 2)") is Err(_))
}

///|
test "exec_file: float converts integer to float" {
  match exec_b("f = float(3)") {
    Ok(m) => assert_true(g(m, "f") == Some(@value.Value::Float(3.0)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: abs returns absolute value of negative integer" {
  match exec_b("n = abs(-7)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(7N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: abs returns absolute value of negative float" {
  match exec_b("f = abs(-2.5)") {
    Ok(m) => assert_true(g(m, "f") == Some(@value.Value::Float(2.5)))
    Err(e) => fail(e.to_string())
  }
}

// --- min, max, sorted, reversed ---

///|
test "exec_file: min returns smallest element from list" {
  match exec_b("n = min([3, 1, 4, 1, 5])") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: max returns largest element from list" {
  match exec_b("n = max([3, 1, 4, 1, 5])") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(5N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: min of multiple positional args" {
  match exec_b("n = min(5, 2, 8)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(2N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: sorted returns a new list in ascending order" {
  match exec_b("r = sorted([3, 1, 4, 1, 5, 9])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 6)
          assert_true(l[0] == @value.Value::Int(1N))
          assert_true(l[5] == @value.Value::Int(9N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: reversed returns elements in reverse order" {
  match exec_b("r = reversed([1, 2, 3])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[0] == @value.Value::Int(3N))
          assert_true(l[2] == @value.Value::Int(1N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- enumerate, zip ---

///|
test "exec_file: enumerate wraps each element with its index" {
  match exec_b("r = enumerate([\"a\", \"b\"])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 2)
          match l[0] {
            @value.Value::Tuple(t) => assert_true(t[0] == @value.Value::Int(0N))
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: enumerate start in Int64 but not Int32 range returns correct index" {
  match exec_b("r = list(enumerate([1], 5000000000))") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 1)
          match l[0] {
            @value.Value::Tuple(t) =>
              assert_true(t[0] == @value.Value::Int(5000000000N))
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: enumerate start beyond Int64 raises out-of-range error" {
  assert_true(
    emsg("list(enumerate([1], 10000000000000000000))").contains("out of range"),
  )
}

///|
test "exec_file: str.replace count beyond Int64 raises out-of-range error" {
  assert_true(
    emsg("\"abc\".replace(\"a\", \"b\", 10000000000000000000)").contains(
      "out of range",
    ),
  )
}

///|
test "exec_file: str.split maxsplit beyond Int64 raises out-of-range error" {
  assert_true(
    emsg("\"a,b,c\".split(\",\", 10000000000000000000)").contains(
      "out of range",
    ),
  )
}

///|
test "exec_file: str.rsplit maxsplit beyond Int64 raises out-of-range error" {
  assert_true(
    emsg("\"a,b,c\".rsplit(\",\", 10000000000000000000)").contains(
      "out of range",
    ),
  )
}

///|
test "exec_file: zip pairs elements from two sequences" {
  match exec_b("r = zip([1, 2], [\"a\", \"b\"])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 2)
          match l[0] {
            @value.Value::Tuple(t) => {
              assert_true(t[0] == @value.Value::Int(1N))
              match t[1] {
                @value.Value::String(s) => assert_eq(s.raw(), "a")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: zip with no arguments produces empty list" {
  match exec_b("r = zip()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- any, all ---

///|
test "exec_file: any returns true when at least one element is truthy" {
  match exec_b("r = any([False, False, True])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: any returns false when all elements are falsy" {
  match exec_b("r = any([0, False, \"\"])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: all returns true when every element is truthy" {
  match exec_b("r = all([1, True, \"x\"])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: all returns false when any element is falsy" {
  match exec_b("r = all([1, 0, True])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

// --- hash ---

///|
test "exec_file: hash produces a deterministic integer for a string" {
  match exec_b("h1 = hash(\"abc\")\nh2 = hash(\"abc\")") {
    Ok(m) => {
      let h1 = g(m, "h1")
      let h2 = g(m, "h2")
      assert_true(h1 == h2)
      assert_true(h1 is Some(@value.Value::Int(_)))
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: hash raises error for unhashable type" {
  assert_true(exec_b("hash([1, 2])") is Err(_))
}

// --- fail ---

///|
test "exec_file: fail raises error with the provided message" {
  match exec_b("fail(\"something went wrong\")") {
    Err(e) => assert_true(e.to_string().contains("something went wrong"))
    Ok(_) => assert_true(false)
  }
}

// --- hasattr, getattr ---

///|
test "exec_file: hasattr returns true when attribute exists on string" {
  match exec_b("r = hasattr(\"hello\", \"upper\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: hasattr returns false when attribute does not exist" {
  match exec_b("r = hasattr(42, \"upper\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: getattr retrieves existing attribute" {
  match exec_b("m = getattr(\"hello\", \"upper\")") {
    Ok(m_) =>
      match g(m_, "m") {
        Some(@value.Value::BoundMethod(_)) => ()
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: getattr returns default when attribute is missing" {
  match exec_b("r = getattr(42, \"upper\", None)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::None))
    Err(e) => fail(e.to_string())
  }
}

// --- list, tuple, dict, set constructors ---

///|
test "exec_file: list() with no argument produces empty list" {
  match exec_b("r = list()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list converts tuple to list" {
  match exec_b("r = list((1, 2, 3))") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: tuple() with no argument produces empty tuple" {
  match exec_b("r = tuple()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Tuple(t)) => assert_eq(t.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: tuple converts list to tuple" {
  match exec_b("r = tuple([1, 2, 3])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Tuple(t)) => assert_eq(t.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict() with no argument produces empty dict" {
  match exec_b("r = dict()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Dict(d)) => assert_eq(d.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict() with keyword arguments sets those keys" {
  match exec_b("r = dict(x=1, y=2)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Dict(d)) => assert_eq(d.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set() with no argument produces empty set" {
  match exec_b("r = set()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set converts list and deduplicates elements" {
  match exec_b("r = set([1, 2, 1, 3])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- print (through Thread) ---

///|
test "exec_file: print sends output through Thread print callback" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match
    exec_file(t, "<test>", "print(\"hello\", \"world\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(@utf8.decode_lossy(msgs[0][:]), "hello world")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: print outputs Bytes value as raw bytes, not repr" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match exec_file(t, "<test>", "print(b\"hello\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"hello")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: print outputs Bytes with hex escapes as raw bytes" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match exec_file(t, "<test>", "print(b\"\\x61\\x62\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"ab")
    }
    Err(e) => fail(e.to_string())
  }
}

// --- print: byte-faithful output ---

///|
test "exec_file: print emits raw bytes for invalid-UTF-8 string slice" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  // "é" encodes as [0xC3, 0xA9]; "é"[0] is [0xC3] — invalid UTF-8 alone.
  // The output must be the raw byte 0xC3, not the U+FFFD replacement (ef bf bd).
  match exec_file(t, "<test>", "print(\"é\"[0])", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc3")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: print emits raw bytes for invalid-UTF-8 string range slice" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match exec_file(t, "<test>", "print(\"é\"[0:1])", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc3")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: join emits raw bytes for invalid-UTF-8 string elements" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match
    exec_file(t, "<test>", "print(\"\".join([\"é\"[0]]))", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc3")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: percent-c emits U+FFFD for invalid-UTF-8 single-byte string" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  // go: DecodeRuneInString("\xc3") → (U+FFFD, 1); WriteRune(U+FFFD) = ef bf bd.
  // %c is a rune-formatting verb, not a raw-byte sink.
  match
    exec_file(t, "<test>", "print(\"%c\" % \"é\"[0])", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xef\xbf\xbd")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: percent-c emits correct UTF-8 for valid emoji string" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match exec_file(t, "<test>", "print(\"%c\" % \"😀\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xf0\x9f\x98\x80")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: percent-s preserves raw bytes of invalid-UTF-8 string" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match
    exec_file(t, "<test>", "print(\"%s\" % \"é\"[0])", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc3")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str_format preserves raw bytes of invalid-UTF-8 string" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match
    exec_file(
      t,
      "<test>",
      "print(\"{}\".format(\"é\"[0]))",
      Options::default(),
    ) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc3")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str() returns identity for invalid-UTF-8 string" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  match exec_file(t, "<test>", "print(str(\"é\"[0]))", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc3")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: print with invalid-UTF-8 sep emits raw separator bytes" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  // sep is "é"[0] = [0xC3]; output should be "a\xc3b"
  match
    exec_file(
      t,
      "<test>",
      "print(\"a\", \"b\", sep=\"é\"[0])",
      Options::default(),
    ) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"a\xc3b")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str_format emits valid UTF-8 for non-BMP chars in template literal" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  // "😀" = U+1F600 encodes as f0 9f 98 80 in UTF-8. If str_format wrongly
  // encodes the template char-by-char as UTF-16 code units (surrogate halves),
  // it would emit the CESU-8 sequence ed a0 bd ed b8 80 instead.
  match
    exec_file(t, "<test>", "print(\"😀{}\".format(1))", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xf0\x9f\x98\x801")
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str_format emits raw bytes for invalid-UTF-8 in template literal" {
  let msgs : Array[Bytes] = []
  let t = Thread::with_print("test", fn(_, bytes) { msgs.push(bytes) })
  // Template "é"[0] + "{}" has the invalid byte 0xc3 in the literal part.
  // It should be emitted as-is, not replaced with U+FFFD (ef bf bd).
  match
    exec_file(
      t,
      "<test>",
      "x = \"é\"[0] + \"{}\"\nprint(x.format(1))",
      Options::default(),
    ) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], b"\xc31")
    }
    Err(e) => fail(e.to_string())
  }
}

// --- List methods ---

///|
test "exec_file: list.append adds element to end of list" {
  match exec_b("lst = [1, 2]\nlst.append(3)\nn = len(lst)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.extend adds all elements from iterable" {
  match exec_b("lst = [1, 2]\nlst.extend([3, 4])\nn = len(lst)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(4N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.pop removes and returns last element" {
  match exec_b("lst = [1, 2, 3]\nv = lst.pop()") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::Int(3N)))
      match g(m, "lst") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 2)
        _ => assert_true(false)
      }
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.remove deletes first matching element" {
  match exec_b("lst = [1, 2, 3, 2]\nlst.remove(2)\nn = len(lst)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.index returns position of first matching element" {
  match exec_b("i = [10, 20, 30].index(20)") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.index rejects more than three positional args" {
  match exec_b("i = [1, 2].index(1, 0, 2, 99)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("got 4 arguments, want at most 3"))
  }
}

///|
test "exec_file: list.insert places element at given index" {
  match exec_b("lst = [1, 3]\nlst.insert(1, 2)") {
    Ok(m) =>
      match g(m, "lst") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[1] == @value.Value::Int(2N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list method error messages use nameErr style" {
  match exec_b("[1, 2].pop(\"x\")") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("pop: for parameter 1: got string, want int"),
      )
  }
  match exec_b("[].pop()") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(e.msg().contains("pop: index -1 out of range: empty list"))
  }
  match exec_b("[1].insert(0)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("insert: got 1 arguments, want 2"))
  }
  match exec_b("[1].insert(\"x\", 9)") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("insert: for parameter 1: got string, want int"),
      )
  }
  match exec_b("[1].remove(1, 2)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("remove: got 2 arguments, want 1"))
  }
  match exec_b("[1, 2].index(1, \"x\")") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("index: invalid start index: got string, want int"),
      )
  }
}

// --- Dict methods ---

///|
test "exec_file: dict.get returns value for existing key" {
  match exec_b("v = {\"x\": 1}.get(\"x\")") {
    Ok(m) => assert_true(g(m, "v") == Some(@value.Value::Int(1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.get returns None when key is absent" {
  match exec_b("v = {}.get(\"x\")") {
    Ok(m) => assert_true(g(m, "v") == Some(@value.Value::None))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.get returns default when key is absent and default provided" {
  match exec_b("v = {}.get(\"x\", 42)") {
    Ok(m) => assert_true(g(m, "v") == Some(@value.Value::Int(42N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.keys returns list of keys in insertion order" {
  match exec_b("ks = {\"a\": 1, \"b\": 2}.keys()") {
    Ok(m) =>
      match g(m, "ks") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.values returns list of values" {
  match exec_b("vs = {\"a\": 1, \"b\": 2}.values()") {
    Ok(m) =>
      match g(m, "vs") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.items returns list of key-value tuples" {
  match exec_b("it = {\"a\": 1}.items()") {
    Ok(m) =>
      match g(m, "it") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 1)
          assert_true(l[0] is @value.Value::Tuple(_))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.pop removes key and returns its value" {
  match exec_b("d = {\"x\": 99}\nv = d.pop(\"x\")") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::Int(99N)))
      match g(m, "d") {
        Some(@value.Value::Dict(d)) => assert_eq(d.length(), 0)
        _ => assert_true(false)
      }
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.update merges another dict's entries" {
  match exec_b("d = {\"a\": 1}\nd.update({\"b\": 2})") {
    Ok(m) =>
      match g(m, "d") {
        Some(@value.Value::Dict(d)) => assert_eq(d.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.update accepts a general iterable of two-element pairs" {
  match exec_b("d = {}\nd.update([range(2)])") {
    Ok(m) =>
      match g(m, "d") {
        Some(@value.Value::Dict(d)) => {
          assert_eq(d.length(), 1)
          assert_true(
            d.get(@value.Value::Int(0N)) == Ok(Some(@value.Value::Int(1N))),
          )
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.get rejects more than two positional args" {
  match exec_b("v = {1: 2}.get(1, 2, 3)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("got 3 arguments, want at most 2"))
  }
}

///|
test "exec_file: dict.pop rejects more than two positional args" {
  match exec_b("v = {1: 2}.pop(1, 2, 3)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("got 3 arguments, want at most 2"))
  }
}

///|
test "exec_file: dict.setdefault rejects more than two positional args" {
  match exec_b("v = {1: 2}.setdefault(1, 2, 3)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("got 3 arguments, want at most 2"))
  }
}

///|
test "exec_file: dict() reports the offending pair length with a dict prefix" {
  match exec_b("d = dict([(1, 2, 3)])") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e
        .msg()
        .contains(
          "dict: dictionary update sequence element #0 has length 3, want 2",
        ),
      )
  }
}

///|
test "exec_file: dict.setdefault inserts key with default when absent" {
  match exec_b("d = {}\nv = d.setdefault(\"x\", 42)") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::Int(42N)))
      match g(m, "d") {
        Some(@value.Value::Dict(d)) => assert_eq(d.length(), 1)
        _ => assert_true(false)
      }
    }
    Err(e) => fail(e.to_string())
  }
}

// --- String methods ---

///|
test "exec_file: string.upper converts all characters to uppercase" {
  match exec_b("s = \"hello\".upper()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "HELLO")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.lower converts all characters to lowercase" {
  match exec_b("s = \"HELLO\".lower()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.strip removes leading and trailing whitespace" {
  match exec_b("s = \"  hello  \".strip()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.startswith returns true when string starts with prefix" {
  match exec_b("r = \"hello\".startswith(\"he\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.endswith returns true when string ends with suffix" {
  match exec_b("r = \"hello\".endswith(\"lo\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.find returns index of first occurrence" {
  match exec_b("i = \"hello world\".find(\"world\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(6N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.find returns -1 when substring is absent" {
  match exec_b("i = \"hello\".find(\"xyz\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(-1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.replace substitutes all occurrences" {
  match exec_b("s = \"aabbaa\".replace(\"aa\", \"x\")") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "xbbx")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.split divides string at separator" {
  match exec_b("parts = \"a,b,c\".split(\",\")") {
    Ok(m) =>
      match g(m, "parts") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.join concatenates parts with separator" {
  match exec_b("s = \", \".join([\"a\", \"b\", \"c\"])") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "a, b, c")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.count returns number of non-overlapping occurrences" {
  match exec_b("n = \"abcabc\".count(\"ab\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(2N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.capitalize uppercases first character and lowercases rest" {
  match exec_b("s = \"hELLO\".capitalize()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "Hello")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.index returns position when substring is found" {
  match exec_b("i = \"hello world\".index(\"world\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(6N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.index raises error when substring is absent" {
  assert_true(exec_b("\"hello\".index(\"xyz\")") is Err(_))
}

///|
test "exec_file: string.rfind returns index of last occurrence" {
  match exec_b("i = \"abcabc\".rfind(\"ab\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.rfind returns -1 when substring is absent" {
  match exec_b("i = \"hello\".rfind(\"xyz\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(-1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for alphabetic string" {
  match exec_b("r = \"hello\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns false when string contains digit" {
  match exec_b("r = \"hello1\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isdigit returns true for digit-only string" {
  match exec_b("r = \"123\".isdigit()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalnum returns true for alphanumeric string" {
  match exec_b("r = \"abc123\".isalnum()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isdigit returns true for Unicode decimal digit" {
  match exec_b("r = \"\u{0661}\".isdigit()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalnum returns true for string with Unicode decimal digit" {
  match exec_b("r = \"a\u{0661}\".isalnum()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for CJK ideograph (Lo)" {
  match exec_b("r = \"\u{4E00}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for Old Hungarian capital letter (Lu, U+10C80)" {
  match exec_b("r = \"\u{10C80}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns false for Imperial Aramaic Mirrored Yod (So, U+10877)" {
  match exec_b("r = \"\u{10877}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for Hiragana letter (Lo)" {
  match exec_b("r = \"\u{3042}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for Hangul syllable (Lo)" {
  match exec_b("r = \"\u{D55C}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for Hebrew letter (Lo)" {
  match exec_b("r = \"\u{05D0}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for modifier letter (Lm)" {
  match exec_b("r = \"\u{02B0}\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalnum returns true for CJK ideograph (Lo)" {
  match exec_b("r = \"\u{4E00}\".isalnum()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.islower returns true when all cased chars are lowercase" {
  match exec_b("r = \"hello\".islower()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isupper returns true when all cased chars are uppercase" {
  match exec_b("r = \"HELLO\".isupper()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isspace returns true for whitespace-only string" {
  match exec_b("r = \"   \".isspace()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.title converts to titlecase" {
  match exec_b("s = \"hello world\".title()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "Hello World")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.partition splits at first occurrence" {
  match exec_b("r = \"hello world\".partition(\" \")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Tuple(t)) => {
          assert_eq(t.length(), 3)
          match t[0] {
            @value.Value::String(s) => assert_eq(s.raw(), "hello")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.removeprefix removes matching prefix" {
  match exec_b("s = \"hello\".removeprefix(\"he\")") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "llo")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.removeprefix returns original when prefix absent" {
  match exec_b("s = \"hello\".removeprefix(\"xyz\")") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.removesuffix removes matching suffix" {
  match exec_b("s = \"hello\".removesuffix(\"lo\")") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hel")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: removeprefix/removesuffix report descriptive error messages" {
  match exec_b("\"abc\".removeprefix()") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(e.msg().contains("removeprefix: got 0 arguments, want 1"))
  }
  match exec_b("\"abc\".removeprefix(1)") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("removeprefix: for parameter 1: got int, want string"),
      )
  }
  match exec_b("\"abc\".removesuffix(1)") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("removesuffix: for parameter 1: got int, want string"),
      )
  }
}

///|
test "exec_file: string.splitlines splits at newline characters" {
  match exec_b("r = \"a\\nb\\nc\".splitlines()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.elems returns string.elems type" {
  match exec_b("r = \"abc\".elems()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::StringElems(e)) =>
          assert_eq(e.source_string().byte_len(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.elem_ords returns string.elems type (ords mode)" {
  match exec_b("r = \"ABC\".elem_ords()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::StringElems(e)) => {
          assert_true(e.is_ords())
          assert_eq(e.source_string().byte_len(), 3)
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- Set methods ---

///|
test "exec_file: set.add inserts element into set" {
  match exec_b("s = set()\ns.add(1)\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.discard removes element without error when absent" {
  match exec_b("s = {1, 2}\ns.discard(9)\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(2N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.remove removes existing element" {
  match exec_b("s = {1, 2}\ns.remove(1)\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(1N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.remove raises error when element is absent" {
  assert_true(exec_b("s = {1}\ns.remove(9)") is Err(_))
}

///|
test "exec_file: set.clear removes all elements" {
  match exec_b("s = {1, 2, 3}\ns.clear()\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(0N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.pop removes and returns an arbitrary element" {
  match exec_b("s = {42}\nv = s.pop()") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::Int(42N)))
      match g(m, "s") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 0)
        _ => assert_true(false)
      }
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.pop raises error when set is empty" {
  assert_true(exec_b("set().pop()") is Err(_))
}

///|
test "exec_file: set.union returns new set with all elements from both sets" {
  match exec_b("r = {1, 2}.union({2, 3})") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.intersection returns elements common to both sets" {
  match exec_b("r = {1, 2, 3}.intersection({2, 3, 4})") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.difference returns elements in self but not in other" {
  match exec_b("r = {1, 2, 3}.difference({2, 3})") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 1)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.symmetric_difference returns elements in exactly one set" {
  match exec_b("r = {1, 2, 3}.symmetric_difference({2, 3, 4})") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.issubset returns true when all elements are in other" {
  match exec_b("r = {1, 2}.issubset({1, 2, 3})") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.issubset returns false when self has element not in other" {
  match exec_b("r = {1, 4}.issubset({1, 2, 3})") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.issuperset returns true when self contains all of other" {
  match exec_b("r = {1, 2, 3}.issuperset({1, 2})") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.update adds all elements from other into self" {
  match exec_b("s = {1, 2}\ns.update({2, 3, 4})\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(4N)))
    Err(e) => fail(e.to_string())
  }
}

// --- dict.clear and dict.popitem ---

///|
test "exec_file: dict.clear removes all entries" {
  match exec_b("d = {\"a\": 1, \"b\": 2}\nd.clear()\nn = len(d)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(0N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.popitem removes and returns an item as tuple" {
  match exec_b("d = {\"x\": 1}\nt = d.popitem()\nn = len(d)") {
    Ok(m) => {
      assert_true(g(m, "n") == Some(@value.Value::Int(0N)))
      assert_true(g(m, "t") is Some(@value.Value::Tuple(_)))
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.popitem raises error when dict is empty" {
  assert_true(exec_b("{}.popitem()") is Err(_))
}

// --- chr and ord ---

///|
test "exec_file: chr converts code point to single-character string" {
  match exec_b("s = chr(65)") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "A")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: chr(0) returns null character" {
  match exec_b("s = chr(0)") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.byte_len(), 1)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: chr raises error for code point above valid Unicode range" {
  assert_true(exec_b("chr(0x110000)") is Err(_))
}

///|
test "exec_file: ord returns code point of single-character string" {
  match exec_b("n = ord(\"A\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(65N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: ord raises error for empty string" {
  assert_true(exec_b("ord(\"\")") is Err(_))
}

///|
test "exec_file: ord raises error for string with more than one character" {
  assert_true(exec_b("ord(\"ab\")") is Err(_))
}

///|
test "exec_file: chr/ord error messages use nameErr style" {
  match exec_b("chr(1, 2)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("chr: got 2 arguments, want 1"))
  }
  match exec_b("chr(\"x\")") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("chr: got string, want int"))
  }
  match exec_b("ord(1, 2)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("ord: got 2 arguments, want 1"))
  }
  match exec_b("ord(\"ab\")") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("ord: string encodes 2 Unicode code points, want 1"),
      )
  }
  match exec_b("ord(5)") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(e.msg().contains("ord: got int, want string or bytes"))
  }
}

///|
test "exec_file: chr maps surrogate codepoints to replacement character U+FFFD" {
  // codepoints in 0xD800–0xDFFF must return U+FFFD, not abort
  let cases = [0xD800, 0xDBFF, 0xDC00, 0xDFFF]
  for cp in cases {
    match exec_b("s = chr(\{cp})") {
      Ok(m) =>
        match g(m, "s") {
          Some(@value.Value::String(s)) => assert_eq(s.raw(), "\u{FFFD}")
          _ => assert_true(false)
        }
      Err(e) => fail(e.to_string())
    }
  }
}

///|
test "exec_file: chr codepoints adjacent to surrogate block are returned as-is" {
  match exec_b("s = chr(0xD7FF)") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "\u{D7FF}")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
  match exec_b("s = chr(0xE000)") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "\u{E000}")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- Lambda ---

///|
test "exec_file: lambda produces a callable value" {
  match exec_b("f = lambda x: x + 1\nr = f(41)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Int(42N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: lambda with no parameters returns constant" {
  match exec_b("f = lambda: 99\nr = f()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Int(99N)))
    Err(e) => fail(e.to_string())
  }
}

// --- Comprehensions ---

///|
test "exec_file: list comprehension transforms and filters elements" {
  match exec_b("r = [x * 2 for x in [1, 2, 3, 4] if x > 2]") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 2)
          assert_true(l[0] == @value.Value::Int(6N))
          assert_true(l[1] == @value.Value::Int(8N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict comprehension builds a mapping from iterable" {
  match exec_b("d = {x: x * x for x in [1, 2, 3]}") {
    Ok(m) =>
      match g(m, "d") {
        Some(@value.Value::Dict(d)) => {
          assert_eq(d.length(), 3)
          let key = @value.Value::Int(2N)
          assert_true(d.get(key) == Ok(Some(@value.Value::Int(4N))))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set comprehension deduplicates elements" {
  match exec_b("s = {x % 3 for x in [0, 1, 2, 3, 4, 5]}") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::Set(s)) => assert_eq(s.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- Function features ---

///|
test "exec_file: function with default parameter uses default when omitted" {
  match exec_b("def f(x, y=10):\n  return x + y\nr = f(5)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Int(15N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: function with star args collects extra positional arguments" {
  match exec_b("def f(*args):\n  return len(args)\nr = f(1, 2, 3)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: function with keyword args collects extra keyword arguments" {
  match exec_b("def f(**kwargs):\n  return len(kwargs)\nr = f(x=1, y=2)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Int(2N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: recursion limit prevents infinite recursion" {
  let t = Thread::new("test")
  let result = exec_file(
    t,
    "<test>",
    "def f(n):\n  return f(n + 1)\nf(0)",
    Options::default().with_allow_recursion(true),
  )
  assert_true(result is Err(_))
}

// --- bytes constructor ---

///|
test "exec_file: bytes constructor accepts a bytes literal" {
  match exec_b("r = bytes(b\"ABC\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Bytes(b)) => assert_eq(b.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: bytes constructor accepts a list of ints" {
  match exec_b("r = bytes([65, 66, 67])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::Bytes(b)) => {
          assert_eq(b.length(), 3)
          assert_eq(b[0], 65)
          assert_eq(b[1], 66)
          assert_eq(b[2], 67)
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: bytes constructor raises error on non-byte integer" {
  assert_true(exec_b("bytes([300])") is Err(_))
}

///|
test "exec_file: bytes constructor raises error on wrong type" {
  assert_true(exec_b("bytes(1)") is Err(_))
}

// --- bytes.elems ---

///|
test "exec_file: bytes.elems returns list of integer byte values" {
  match exec_b("r = list(b\"ABC\".elems())") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[0] == @value.Value::Int(65N))
          assert_true(l[1] == @value.Value::Int(66N))
          assert_true(l[2] == @value.Value::Int(67N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: bytes.elems on empty bytes returns empty list" {
  match exec_b("r = list(b\"\".elems())") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- str.format() extended ---

///|
test "exec_file: str.format supports indexed positional {0}" {
  match exec_b("r = \"{0} and {1}\".format(\"a\", \"b\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "a and b")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.format supports keyword {name}" {
  match exec_b("r = \"hello {name}\".format(name=\"world\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "hello world")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.format supports !r conversion" {
  match exec_b("r = \"{!r}\".format(\"hi\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "\"hi\"")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.format supports escaped braces" {
  match exec_b("r = \"{{ {0} }}\".format(\"x\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "{ x }")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.format raises error on missing keyword" {
  assert_true(exec_b("\"{missing}\".format()") is Err(_))
}

///|
test "exec_file: str.format raises error when mixing auto and manual indexing" {
  assert_true(exec_b("\"{} {0}\".format(\"a\", \"b\")") is Err(_))
}

///|
test "exec_file: str.format raises 'nested replacement fields' for { in name part" {
  match exec_b("\"{ {} }\".format(1)") {
    Err(e) =>
      assert_true(
        e.to_string().contains("nested replacement fields not supported"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "exec_file: str.format raises 'format spec features not supported' for { in spec part" {
  match exec_b("\"{:{}}\".format(1, 2)") {
    Err(e) =>
      assert_true(
        e
        .to_string()
        .contains("format spec features not supported in replacement fields: {"),
      )
    Ok(_) => fail("expected error")
  }
}

///|
test "exec_file: str.format spec error includes full spec text when { appears after other spec characters" {
  match exec_b("\"{:0{}}\".format(1, 2)") {
    Err(e) =>
      assert_true(
        e
        .to_string()
        .contains(
          "format spec features not supported in replacement fields: 0{",
        ),
      )
    Ok(_) => fail("expected error")
  }
}

// --- sorted with key= and reverse= ---

///|
test "exec_file: sorted with key= sorts by key function result" {
  match exec_b("r = sorted([\"bb\", \"a\", \"ccc\"], key=len)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          match l[0] {
            @value.Value::String(s) => assert_eq(s.raw(), "a")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: sorted with reverse=True returns descending order" {
  match exec_b("r = sorted([1, 3, 2], reverse=True)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[0] == @value.Value::Int(3N))
          assert_true(l[2] == @value.Value::Int(1N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: sorted accepts key and reverse positionally" {
  match exec_b("r = sorted([\"bb\", \"a\", \"ccc\"], len, True)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          match l[0] {
            @value.Value::String(s) => assert_eq(s.raw(), "ccc")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: sorted rejects non-bool reverse" {
  match exec_b("r = sorted([1, 2], reverse=1)") {
    Ok(_) => assert_true(false)
    Err(e) =>
      assert_true(
        e.msg().contains("for parameter \"reverse\": got int, want bool"),
      )
  }
}

///|
test "exec_file: sorted rejects more than three positional args" {
  match exec_b("r = sorted([1], len, True, 4)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("got 4 arguments, want at most 3"))
  }
}

///|
test "exec_file: sorted rejects None key passed positionally" {
  match exec_b("r = sorted([1, 2, 3], None)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("got NoneType, want callable"))
  }
}

// --- min/max with key= ---

///|
test "exec_file: min with key= returns element with smallest key" {
  match exec_b("r = min([\"bb\", \"a\", \"ccc\"], key=len)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "a")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: max with key= returns element with largest key" {
  match exec_b("r = max([\"bb\", \"a\", \"ccc\"], key=len)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "ccc")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- print with sep= and end= ---

///|
test "exec_file: print with sep= uses custom separator" {
  let captured : Array[Bytes] = []
  let t = Thread::with_print("<test>", fn(_, bytes) { captured.push(bytes) })
  ignore(
    exec_file(t, "<test>", "print(1, 2, 3, sep=\"-\")", Options::default()),
  )
  assert_true(
    captured.length() > 0 && @utf8.decode_lossy(captured[0][:]) == "1-2-3",
  )
}

///|
test "exec_file: print with sep= and no args outputs empty string" {
  let captured : Array[Bytes] = []
  let t = Thread::with_print("<test>", fn(_, bytes) { captured.push(bytes) })
  ignore(exec_file(t, "<test>", "print(sep=\",\")", Options::default()))
  assert_true(captured.length() > 0 && captured[0] == b"")
}

// --- dir() ---

///|
test "exec_file: dir on string returns sorted method names" {
  match exec_b("r = dir(\"hello\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_true(l.length() > 0)
          assert_true(l[0] is @value.Value::String(_))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dir on list returns sorted method names" {
  match exec_b("r = dir([])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_true(l.length() > 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dir on int returns empty list" {
  match exec_b("r = dir(42)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- string.rsplit ---

///|
test "exec_file: str.rsplit with sep splits from right" {
  match exec_b("r = \"a,b,c\".rsplit(\",\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          match l[0] {
            @value.Value::String(s) => assert_eq(s.raw(), "a")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.rsplit with maxsplit limits from right" {
  match exec_b("r = \"a,b,c,d\".rsplit(\",\", 2)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          match l[0] {
            @value.Value::String(s) => assert_eq(s.raw(), "a,b")
            _ => assert_true(false)
          }
          match l[2] {
            @value.Value::String(s) => assert_eq(s.raw(), "d")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- string.codepoints and codepoint_ords ---

///|
test "exec_file: str.codepoints returns list of single-char strings" {
  match exec_b("r = list(\"abc\".codepoints())") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          match l[0] {
            @value.Value::String(s) => assert_eq(s.raw(), "a")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.codepoint_ords returns list of code point integers" {
  match exec_b("r = list(\"ABC\".codepoint_ords())") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[0] == @value.Value::Int(65N))
          assert_true(l[1] == @value.Value::Int(66N))
          assert_true(l[2] == @value.Value::Int(67N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.codepoints on empty string returns empty list" {
  match exec_b("r = list(\"\".codepoints())") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.splitlines without keepends splits at newlines" {
  match exec_b("r = \"a\\nb\\nc\".splitlines()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(
            l[0] == @value.Value::String(@value.StarlarkString::new("a")),
          )
          assert_true(
            l[1] == @value.Value::String(@value.StarlarkString::new("b")),
          )
          assert_true(
            l[2] == @value.Value::String(@value.StarlarkString::new("c")),
          )
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.splitlines with keepends=True keeps line endings" {
  match exec_b("r = \"a\\nb\\nc\".splitlines(True)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(
            l[0] == @value.Value::String(@value.StarlarkString::new("a\n")),
          )
          assert_true(
            l[1] == @value.Value::String(@value.StarlarkString::new("b\n")),
          )
          assert_true(
            l[2] == @value.Value::String(@value.StarlarkString::new("c")),
          )
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: str.splitlines rejects non-bool keepends argument" {
  match exec_b("r = \"a\\nb\".splitlines(1)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("want bool"))
  }
}

///|
test "exec_file: str.splitlines on empty string returns empty list" {
  match exec_b("r = \"\".splitlines(True)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- builtin argument-validation error wording (starlark-go parity) ---

///|
test "exec_file: abs reports type error without a name prefix" {
  assert_eq(emsg("abs(\"0\")"), "got string, want int or float")
}

///|
test "exec_file: positional builtins report arg-count like UnpackPositionalArgs" {
  assert_eq(emsg("len()"), "len: got 0 arguments, want 1")
  assert_eq(emsg("len(1, 2)"), "len: got 2 arguments, want 1")
  assert_eq(emsg("repr(1, 2)"), "repr: got 2 arguments, want 1")
  assert_eq(emsg("reversed(1, 2)"), "reversed: got 2 arguments, want 1")
  assert_eq(emsg("dir()"), "dir: got 0 arguments, want 1")
  assert_eq(emsg("dir(1, 2)"), "dir: got 2 arguments, want 1")
  assert_eq(emsg("all([1], [2])"), "all: got 2 arguments, want 1")
  assert_eq(emsg("any([1], [2])"), "any: got 2 arguments, want 1")
  assert_eq(emsg("bool(1, 2)"), "bool: got 2 arguments, want at most 1")
  assert_eq(emsg("list(1, 2)"), "list: got 2 arguments, want at most 1")
  assert_eq(emsg("tuple(1, 2)"), "tuple: got 2 arguments, want at most 1")
  assert_eq(emsg("set(1, 2)"), "set: got 2 arguments, want at most 1")
}

///|
test "exec_file: positional builtins reject keyword args with unpack wording" {
  assert_eq(emsg("len(foo=1)"), "len: unexpected keyword arguments")
  assert_eq(emsg("repr(x=1)"), "repr: unexpected keyword arguments")
  assert_eq(emsg("reversed(x=1)"), "reversed: unexpected keyword arguments")
  assert_eq(emsg("all(x=1)"), "all: unexpected keyword arguments")
  assert_eq(emsg("any(x=1)"), "any: unexpected keyword arguments")
  assert_eq(emsg("bool(x=1)"), "bool: unexpected keyword arguments")
  assert_eq(emsg("list(x=1)"), "list: unexpected keyword arguments")
  assert_eq(emsg("tuple(x=1)"), "tuple: unexpected keyword arguments")
  assert_eq(emsg("set(x=1)"), "set: unexpected keyword arguments")
}

///|
test "exec_file: dir keeps the does-not-accept-keyword-arguments wording" {
  assert_eq(emsg("dir(x=1)"), "dir does not accept keyword arguments")
}

///|
test "exec_file: str and bytes report excess args as want exactly 1" {
  assert_eq(emsg("str(1, 2)"), "str: got 2 arguments, want exactly 1")
  assert_eq(
    emsg("bytes(\"a\", \"b\")"),
    "bytes: got 2 arguments, want exactly 1",
  )
}

///|
test "exec_file: str rejects keyword arguments" {
  assert_eq(emsg("str(1, x=2)"), "str does not accept keyword arguments")
}

///|
test "exec_file: list method errors include method name prefix" {
  assert_true(emsg("l=[1,2]; l.pop(5)").contains("pop:"))
  assert_true(emsg("l=[1,2]; l.extend(1)").contains("extend:"))
  assert_true(emsg("l=[1,2]; l.insert('bad', 3)").contains("insert:"))
  assert_true(emsg("l=[1,2]; l.remove(3)").contains("remove:"))
}

///|
test "exec_file: dict method errors include method name prefix" {
  assert_true(emsg("d={}; d.pop('k')").contains("pop:"))
  assert_true(emsg("d={}; d.get([])").contains("get:"))
}

///|
test "exec_file: sorted accepts iterable passed by keyword" {
  match exec_b("r = sorted(iterable=[3, 1, 2])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l[0] == @value.Value::Int(1N))
          assert_true(l[2] == @value.Value::Int(3N))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: sorted with no iterable reports missing argument" {
  assert_eq(emsg("sorted()"), "sorted: missing argument for iterable")
  assert_eq(emsg("sorted(key=len)"), "sorted: missing argument for iterable")
}

///|
test "exec_file: sorted raises conflict error when iterable passed both positionally and by keyword" {
  assert_eq(
    emsg("sorted([1, 2], iterable=[3, 4])"),
    "sorted: got multiple values for keyword argument \"iterable\"",
  )
}

///|
test "exec_file: sorted raises conflict error when key passed both positionally and by keyword" {
  assert_eq(
    emsg("sorted([1, 2], len, key=len)"),
    "sorted: got multiple values for keyword argument \"key\"",
  )
}

///|
test "exec_file: sorted raises conflict error when reverse passed both positionally and by keyword" {
  assert_eq(
    emsg("sorted([1, 2], len, True, reverse=True)"),
    "sorted: got multiple values for keyword argument \"reverse\"",
  )
}

///|
test "exec_file: min checks positional count before keyword args" {
  assert_eq(
    emsg("min(default=5)"),
    "min requires at least one positional argument",
  )
  assert_eq(emsg("max()"), "max requires at least one positional argument")
}

///|
test "exec_file: min/max reject unexpected keyword with unpack wording" {
  assert_eq(
    emsg("min([1, 2], default=5)"),
    "min: unexpected keyword argument \"default\"",
  )
  assert_eq(
    emsg("max([1, 2], foo=5)"),
    "max: unexpected keyword argument \"foo\"",
  )
}

///|
test "exec_file: min/max type-mismatch errors include builtin name and correct operator" {
  assert_eq(emsg("max(1, \"z\")"), "max: string > int not implemented")
  assert_eq(emsg("min([1, \"a\"])"), "min: string < int not implemented")
}

///|
test "exec_file: set with unhashable element error includes builtin name" {
  assert_eq(emsg("set([[1]])"), "set: unhashable type: list")
}

///|
test "exec_file: splitlines/join report parameter index in type errors" {
  assert_eq(
    emsg("\"hi\".splitlines(1)"),
    "splitlines: for parameter 1: got int, want bool",
  )
  assert_eq(
    emsg("\",\".join(5)"),
    "join: for parameter 1: got int, want iterable",
  )
}

///|
test "exec_file: split and strip treat Unicode whitespace as separators" {
  // U+00A0 (no-break space) is whitespace per Go's unicode.IsSpace.
  match exec_b("r = \"a\\u00a0b\".split()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::List(l)) => {
          assert_eq(l.length(), 2)
          assert_true(
            l[0] == @value.Value::String(@value.StarlarkString::new("a")),
          )
          assert_true(
            l[1] == @value.Value::String(@value.StarlarkString::new("b")),
          )
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
  match exec_b("r = \"\\u00a0x\\u00a0\".strip()") {
    Ok(m) =>
      assert_true(
        g(m, "r") == Some(@value.Value::String(@value.StarlarkString::new("x"))),
      )
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int with more than two positional arguments raises error" {
  assert_true(
    emsg("int(1, 10, \"extra\")").contains(
      "int: got 3 arguments, want at most 2",
    ),
  )
}

///|
test "exec_file: int with x keyword and positional argument raises conflict error" {
  assert_eq(
    emsg("int(1, x=2)"),
    "int: got multiple values for keyword argument \"x\"",
  )
}

///|
test "exec_file: int with unknown keyword argument raises error" {
  assert_true(
    emsg("int(y=1)").contains("int: unexpected keyword argument \"y\""),
  )
}

///|
test "exec_file: int with x as keyword argument converts the value" {
  match exec_b("n = int(x=\"42\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::Int(42N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int with base out of the 2-36 range raises error" {
  assert_true(
    emsg("int(\"5\", 37)").contains(
      "int: base must be an integer >= 2 && <= 36",
    ),
  )
  assert_true(
    emsg("int(\"5\", 1)").contains("int: base must be an integer >= 2 && <= 36"),
  )
}

///|
test "exec_file: int on a non-numeric non-string type raises a TypeError" {
  assert_true(emsg("int([1, 2])").contains("int: cannot convert list to int"))
}

///|
test "exec_file: float rejects keyword arguments" {
  assert_true(
    emsg("float(x=1)").contains("float does not accept keyword arguments"),
  )
}

///|
test "exec_file: float with more than one positional argument raises error" {
  assert_true(emsg("float(1, 2)").contains("float got 2 arguments, wants 1"))
}

///|
test "exec_file: float rejects an empty string" {
  assert_true(emsg("float(\"\")").contains("float: empty string"))
}

///|
test "exec_file: float rejects a string that overflows to infinity" {
  assert_true(
    emsg("float(\"1e99999\")").contains("floating-point number too large"),
  )
}

///|
test "exec_file: float parses hex-float with integer mantissa and binary exponent" {
  match exec_b("x = float(\"0x1p4\")") {
    Ok(m) => assert_true(g(m, "x") == Some(@value.Value::Float(16.0)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: float parses hex-float with fractional mantissa" {
  match exec_b("x = float(\"0x1.8p3\")") {
    Ok(m) => assert_true(g(m, "x") == Some(@value.Value::Float(12.0)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: float parses negative hex-float" {
  match exec_b("x = float(\"-0x1p1\")") {
    Ok(m) => assert_true(g(m, "x") == Some(@value.Value::Float(-2.0)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: float parses hex-float with uppercase prefix and exponent marker" {
  match exec_b("x = float(\"0X1P4\")") {
    Ok(m) => assert_true(g(m, "x") == Some(@value.Value::Float(16.0)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: float rejects hex string without p exponent" {
  assert_true(emsg("float(\"0x10\")").contains("invalid float literal"))
}

///|
test "exec_file: float rejects hex-float whose exponent overflows 32-bit integer" {
  assert_true(
    emsg("float(\"0x1p2147483648\")").contains(
      "floating-point number too large",
    ),
  )
}

///|
test "exec_file: fail with non-string sep raises a TypeError" {
  assert_true(
    emsg("fail(\"msg\", sep=123)").contains(
      "fail: for parameter \"sep\": got int, want string",
    ),
  )
}

///|
test "exec_file: fail with unknown keyword argument raises error" {
  assert_true(
    emsg("fail(\"msg\", x=1)").contains(
      "fail: unexpected keyword argument \"x\"",
    ),
  )
}

// --- str edge cases ---

///|
test "exec_file: str with no arguments raises error" {
  assert_eq(emsg("str()"), "str: got 0 arguments, want exactly 1")
}

// --- print keyword argument errors ---

///|
test "exec_file: print with non-string sep raises TypeError" {
  assert_true(emsg("print(1, sep=123)").contains("want string"))
}

///|
test "exec_file: print with unknown keyword argument raises error" {
  assert_true(emsg("print(foo=1)").contains("unexpected keyword argument"))
}

// --- string.rindex ---

///|
test "exec_file: string.rindex returns position of last occurrence" {
  match exec_b("i = \"hello\".rindex(\"l\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(3N)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.rindex raises error when substring is not present" {
  assert_true(emsg("\"hello\".rindex(\"x\")").contains("substring not found"))
}

///|
test "exec_file: string.rindex with end bound limits the search range" {
  match exec_b("i = \"hello\".rindex(\"l\", 0, 3)") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::Int(2N)))
    Err(e) => fail(e.to_string())
  }
}

// --- string.replace with count ---

///|
test "exec_file: string.replace with count stops after the given number of substitutions" {
  match exec_b("s = \"aaa\".replace(\"a\", \"b\", 2)") {
    Ok(m) =>
      assert_true(
        g(m, "s") ==
        Some(@value.Value::String(@value.StarlarkString::new("bba"))),
      )
    Err(e) => fail(e.to_string())
  }
}

// --- function hash ---

///|
test "exec_file: function value is hashable and can be stored in a set" {
  assert_true(exec_b("def f(): pass\ns = {f}") is Ok(_))
}

///|
test "exec_file: two distinct functions compared for equality always return false" {
  match exec_b("def f(): pass\ndef g(): pass\nr = (f == g)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::Bool(false)))
    Err(e) => fail(e.to_string())
  }
}

// --- type() arity error ---

///|
test "exec_file: type with no arguments raises error" {
  assert_true(emsg("type()").contains("one argument"))
}

///|
test "exec_file: type with two arguments raises error" {
  assert_true(emsg("type(1, 2)").contains("one argument"))
}

// --- slice index out of int32 range ---

///|
test "exec_file: slice with start index larger than int32 max raises out-of-range error" {
  assert_true(emsg("x = 'hello'[9999999999:]").contains("out of range"))
}

// --- float() with out-of-range literal string ---

///|
test "exec_file: float string that parses to infinity raises floating-point-too-large error" {
  assert_true(
    emsg("float('1e400')").contains("floating-point number too large"),
  )
}

// --- range() type error ---

///|
test "exec_file: range with non-integer argument raises type error" {
  assert_true(emsg("range('hello')").contains("want int"))
}

// --- dict.pop guard order ---

///|
test "exec_file: dict.pop on empty dict with unhashable key and default returns default" {
  match exec_b("v = {}.pop([9], \"d\")") {
    Ok(m) =>
      match g(m, "v") {
        Some(@value.Value::String(s)) => assert_eq(s.raw(), "d")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.pop on frozen dict with missing key and default raises frozen error" {
  let pre : Map[String, @value.Value] = {}
  let d_val = @value.Value::new_dict()
  if d_val is @value.Value::Dict(d) {
    ignore(d.set(@value.Value::Int(1N), @value.Value::Int(2N)))
    d.freeze()
  }
  pre["frozen_d"] = d_val
  let t = Thread::new("test")
  let result = exec_file_with_predeclared(
    t,
    "<test>",
    "v = frozen_d.pop(99, \"x\")",
    Options::default(),
    Predeclared::from_map(pre),
  )
  match result {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("frozen"))
  }
}

///|
test "exec_file: dict.pop on emptied dict with unhashable key raises unhashable error" {
  match exec_b("d = {1: 'a'}\nd.pop(1)\nv = d.pop([], 'x')") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("unhashable"))
  }
}

// --- sorted key= mutation guard ---

///|
test "exec_file: sorted key= that mutates source list raises during-iteration error" {
  let src =
    #|xs = [3, 1, 2]
    #|r = sorted(xs, key=lambda x: xs.append(x) or x)
  match exec_b(src) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("during iteration"))
  }
}

// --- iteration-lock error message prefixes ---

///|
test "exec_file: list.clear during iteration error matches go wording" {
  let src =
    #|def f():
    #|    xs = [1, 2, 3]
    #|    for _ in xs:
    #|        xs.clear()
    #|f()
  assert_eq(emsg(src), "clear: cannot clear list during iteration")
}

///|
test "exec_file: list.clear on frozen list error matches go wording" {
  let pre : Map[String, @value.Value] = {}
  let list_val = @value.Value::new_list([
    @value.Value::Int(1N),
    @value.Value::Int(2N),
  ])
  if list_val is @value.Value::List(l) {
    l.freeze()
  }
  pre["frozen_xs"] = list_val
  let t = Thread::new("test")
  let result = exec_file_with_predeclared(
    t,
    "<test>",
    "frozen_xs.clear()",
    Options::default(),
    Predeclared::from_map(pre),
  )
  match result {
    Ok(_) => assert_true(false)
    Err(e) => assert_eq(e.msg(), "clear: cannot clear frozen list")
  }
}

///|
test "exec_file: list.append during iteration error includes append: prefix" {
  let src =
    #|def f():
    #|    xs = [1, 2, 3]
    #|    for _ in xs:
    #|        xs.append(4)
    #|f()
  assert_true(emsg(src).contains("append:"))
}

///|
test "exec_file: dict.update during iteration error includes update: prefix" {
  let src =
    #|def f():
    #|    d = {"a": 1}
    #|    for _ in d:
    #|        d.update({"b": 2})
    #|f()
  assert_true(emsg(src).contains("update:"))
}

///|
test "exec_file: dict.update with iterable-of-pairs during iteration error includes update: prefix" {
  let src =
    #|def f():
    #|    d = {"a": 1}
    #|    for _ in d:
    #|        d.update([("b", 2)])
    #|f()
  assert_true(emsg(src).contains("update:"))
}

///|
test "exec_file: dict.update with kwargs during iteration error includes update: prefix" {
  let src =
    #|def f():
    #|    d = {"a": 1}
    #|    for _ in d:
    #|        d.update(b=2)
    #|f()
  assert_true(emsg(src).contains("update:"))
}

// --- list.index BigInt bounds ---

///|
test "exec_file: list.index with BigInt start below Int64 min raises invalid start index" {
  match exec_b("[1, 2, 3].index(2, -9999999999999999999)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("invalid start index"))
  }
}

///|
test "exec_file: list.index with BigInt end above Int64 max raises invalid end index" {
  match exec_b("[1, 2, 3].index(2, 0, 9999999999999999999)") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("invalid end index"))
  }
}

// --- range length overflow ---

///|
test "exec_file: len of range with overflowing length raises no-len error" {
  match exec_b("n = len(range(-(1<<62), 1<<62))") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: iterating range with overflowing length raises no-len error" {
  match exec_b("def f():\n  for x in range(-(1<<62), 1<<62): pass\nf()") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: indexing range with overflowing length raises no-len error" {
  match exec_b("range(-(1<<62), 1<<62)[0]") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: slicing range with overflowing length raises no-len error" {
  match exec_b("range(-(1<<62), 1<<62)[0:2]") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: len of double-overflow range raises no-len error" {
  match exec_b("n = len(range(-(1<<63), (1<<63)-1, 2))") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: iterating double-overflow range raises no-len error" {
  match
    exec_b("def f():\n  for x in range(-(1<<63), (1<<63)-1, 2): pass\nf()") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: indexing double-overflow range raises no-len error" {
  match exec_b("range(-(1<<63), (1<<63)-1, 2)[0]") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

///|
test "exec_file: slicing double-overflow range raises no-len error" {
  match exec_b("range(-(1<<63), (1<<63)-1, 2)[0:2]") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.msg().contains("has no len"))
  }
}

// --- list(range(N)) / tuple(range(N)) oversized materialization ---

///|
test "exec_file: list from range at allocation cap raises excessive-sequence error" {
  assert_true(emsg("list(range(1073741824))").contains("excessive sequence"))
}

///|
test "exec_file: tuple from range at allocation cap raises excessive-sequence error" {
  assert_true(emsg("tuple(range(1073741824))").contains("excessive sequence"))
}

///|
test "exec_file: list from overflow range raises excessive-sequence error" {
  assert_true(
    emsg("list(range(-(1<<62), 1<<62))").contains("excessive sequence"),
  )
}

///|
test "exec_file: tuple from overflow range raises excessive-sequence error" {
  assert_true(
    emsg("tuple(range(-(1<<62), 1<<62))").contains("excessive sequence"),
  )
}

// --- set/enumerate/dict oversized Range ---

///|
test "exec_file: set from range at allocation cap raises excessive-sequence error" {
  assert_true(emsg("set(range(1073741824))").contains("excessive sequence"))
}

///|
test "exec_file: enumerate from range at allocation cap raises excessive-sequence error" {
  assert_true(
    emsg("enumerate(range(1073741824))").contains("excessive sequence"),
  )
}

///|
test "exec_file: dict from range at allocation cap raises excessive-sequence error" {
  assert_true(emsg("dict(range(1073741824))").contains("excessive sequence"))
}

// --- reversed/sorted/extend/star-args oversized Range ---

///|
test "exec_file: reversed from range at allocation cap raises excessive-sequence error" {
  assert_true(
    emsg("reversed(range(1073741824))").contains("excessive sequence"),
  )
}

///|
test "exec_file: sorted from range at allocation cap raises excessive-sequence error" {
  assert_true(emsg("sorted(range(1073741824))").contains("excessive sequence"))
}

///|
test "exec_file: list extend from range at allocation cap raises excessive-sequence error" {
  assert_true(
    emsg("[].extend(range(1073741824))").contains("excessive sequence"),
  )
}

///|
test "exec_file: star-args from range at allocation cap raises excessive-sequence error" {
  assert_true(
    emsg("def f(*a): pass\nf(*range(1073741824))").contains(
      "excessive sequence",
    ),
  )
}

// --- dict() arity error ---

///|
test "exec_file: dict with more than one positional argument raises error" {
  assert_true(emsg("dict(1, 2)").contains("want at most 1"))
}

// --- repr / str / print depth guard ---

///|
test "exec_file: repr of deeply nested acyclic list raises runtime error" {
  let n = @value.repr_limit + 1
  let src = "def b():\n  x = 0\n  for i in range(\{n}):\n    x = [x]\n  return x\nrepr(b())"
  assert_true(emsg(src).contains("maximum recursion depth"))
}

///|
test "exec_file: str of deeply nested acyclic list raises runtime error" {
  let n = @value.repr_limit + 1
  let src = "def b():\n  x = 0\n  for i in range(\{n}):\n    x = [x]\n  return x\nstr(b())"
  assert_true(emsg(src).contains("maximum recursion depth"))
}

///|
test "exec_file: print of deeply nested acyclic list raises runtime error" {
  let n = @value.repr_limit + 1
  let src = "def b():\n  x = 0\n  for i in range(\{n}):\n    x = [x]\n  return x\nprint(b())"
  assert_true(emsg(src).contains("maximum recursion depth"))
}

///|
test "exec_file: repr of shallowly nested list succeeds" {
  let n = @value.repr_limit
  let src = "def b():\n  x = 0\n  for i in range(\{n}):\n    x = [x]\n  return x\nr = repr(b())"
  match exec_b(src) {
    Ok(m) =>
      match m.get("r") {
        Some(@value.Value::String(s)) => assert_true(s.raw().has_prefix("["))
        _ => fail("expected a string result")
      }
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

// --- dotted attribute error wording ---

///|
test "exec_file: tuple dotted attribute error uses .x field or method wording" {
  assert_eq(emsg("(1, 2).foo"), "tuple has no .foo field or method")
}

///|
test "exec_file: int dotted attribute error uses .x field or method wording" {
  assert_eq(emsg("(1).foo"), "int has no .foo field or method")
}

///|
test "exec_file: bool dotted attribute error uses .x field or method wording" {
  assert_eq(emsg("True.foo"), "bool has no .foo field or method")
}

///|
test "exec_file: NoneType dotted attribute error uses .x field or method wording" {
  assert_eq(emsg("None.foo"), "NoneType has no .foo field or method")
}

///|
test "exec_file: range dotted attribute error uses .x field or method wording" {
  assert_eq(emsg("range(3).foo"), "range has no .foo field or method")
}
