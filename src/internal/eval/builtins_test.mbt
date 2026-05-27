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

// --- range ---

///|
test "exec_file: range(stop) produces correct sequence when iterated" {
  match exec_b("r = list(range(5))") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 5)
          assert_true(l.get(0) == @value.Value::IntVal(0L))
          assert_true(l.get(4) == @value.Value::IntVal(4L))
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(0) == @value.Value::IntVal(2L))
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

// --- len ---

///|
test "exec_file: len returns element count of list" {
  match exec_b("n = len([1, 2, 3])") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: len returns byte count of string" {
  match exec_b("n = len(\"hello\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(5L)))
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "42")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "\"hi\"")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "int")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- bool, int, float, abs ---

///|
test "exec_file: bool converts truthy value to True" {
  match exec_b("b = bool(1)") {
    Ok(m) => assert_true(g(m, "b") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: bool() with no argument returns False" {
  match exec_b("b = bool()") {
    Ok(m) => assert_true(g(m, "b") == Some(@value.Value::BoolVal(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int converts float to integer by truncation" {
  match exec_b("n = int(3.9)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int parses decimal string" {
  match exec_b("n = int(\"42\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(42L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int parses hex string with explicit base keyword" {
  match exec_b("n = int(\"ff\", base=16)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(255L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: int converts Bool to integer without TypeError" {
  match exec_b("a = int(True)\nb = int(False)") {
    Ok(m) => {
      assert_true(g(m, "a") == Some(@value.Value::IntVal(1L)))
      assert_true(g(m, "b") == Some(@value.Value::IntVal(0L)))
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
    Ok(m) => assert_true(g(m, "f") == Some(@value.Value::FloatVal(3.0)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: abs returns absolute value of negative integer" {
  match exec_b("n = abs(-7)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(7L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: abs returns absolute value of negative float" {
  match exec_b("f = abs(-2.5)") {
    Ok(m) => assert_true(g(m, "f") == Some(@value.Value::FloatVal(2.5)))
    Err(e) => fail(e.to_string())
  }
}

// --- min, max, sorted, reversed ---

///|
test "exec_file: min returns smallest element from list" {
  match exec_b("n = min([3, 1, 4, 1, 5])") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(1L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: max returns largest element from list" {
  match exec_b("n = max([3, 1, 4, 1, 5])") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(5L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: min of multiple positional args" {
  match exec_b("n = min(5, 2, 8)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(2L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: sorted returns a new list in ascending order" {
  match exec_b("r = sorted([3, 1, 4, 1, 5, 9])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 6)
          assert_true(l.get(0) == @value.Value::IntVal(1L))
          assert_true(l.get(5) == @value.Value::IntVal(9L))
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(0) == @value.Value::IntVal(3L))
          assert_true(l.get(2) == @value.Value::IntVal(1L))
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 2)
          match l.get(0) {
            @value.Value::TupleVal(t) =>
              assert_true(t[0] == @value.Value::IntVal(0L))
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: zip pairs elements from two sequences" {
  match exec_b("r = zip([1, 2], [\"a\", \"b\"])") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 2)
          match l.get(0) {
            @value.Value::TupleVal(t) => {
              assert_true(t[0] == @value.Value::IntVal(1L))
              match t[1] {
                @value.Value::StrVal(s) => assert_eq(s.raw, "a")
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- any, all ---

///|
test "exec_file: any returns true when at least one element is truthy" {
  match exec_b("r = any([False, False, True])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: any returns false when all elements are falsy" {
  match exec_b("r = any([0, False, \"\"])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: all returns true when every element is truthy" {
  match exec_b("r = all([1, True, \"x\"])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: all returns false when any element is falsy" {
  match exec_b("r = all([1, 0, True])") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(false)))
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
      assert_true(h1 is Some(@value.Value::IntVal(_)))
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
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: hasattr returns false when attribute does not exist" {
  match exec_b("r = hasattr(42, \"upper\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: getattr retrieves existing attribute" {
  match exec_b("m = getattr(\"hello\", \"upper\")") {
    Ok(m_) =>
      match g(m_, "m") {
        Some(@value.Value::BoundMethodVal(_)) => ()
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: getattr returns default when attribute is missing" {
  match exec_b("r = getattr(42, \"upper\", None)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::NoneVal))
    Err(e) => fail(e.to_string())
  }
}

// --- list, tuple, dict, set constructors ---

///|
test "exec_file: list() with no argument produces empty list" {
  match exec_b("r = list()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 0)
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 3)
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
        Some(@value.Value::TupleVal(t)) => assert_eq(t.length(), 0)
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
        Some(@value.Value::TupleVal(t)) => assert_eq(t.length(), 3)
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
        Some(@value.Value::DictVal(d)) => assert_eq(d.length(), 0)
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
        Some(@value.Value::DictVal(d)) => assert_eq(d.length(), 2)
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 0)
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- print (through Thread) ---

///|
test "exec_file: print sends output through Thread print callback" {
  let msgs : Array[String] = []
  let t = Thread::with_print("test", fn(msg) { msgs.push(msg) })
  match
    exec_file(t, "<test>", "print(\"hello\", \"world\")", Options::default()) {
    Ok(_) => {
      assert_eq(msgs.length(), 1)
      assert_eq(msgs[0], "hello world")
    }
    Err(e) => fail(e.to_string())
  }
}

// --- List methods ---

///|
test "exec_file: list.append adds element to end of list" {
  match exec_b("lst = [1, 2]\nlst.append(3)\nn = len(lst)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.extend adds all elements from iterable" {
  match exec_b("lst = [1, 2]\nlst.extend([3, 4])\nn = len(lst)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(4L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.pop removes and returns last element" {
  match exec_b("lst = [1, 2, 3]\nv = lst.pop()") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::IntVal(3L)))
      match g(m, "lst") {
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 2)
        _ => assert_true(false)
      }
    }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.remove deletes first matching element" {
  match exec_b("lst = [1, 2, 3, 2]\nlst.remove(2)\nn = len(lst)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.sort orders elements in place" {
  match exec_b("lst = [3, 1, 4, 1]\nlst.sort()") {
    Ok(m) =>
      match g(m, "lst") {
        Some(@value.Value::ListVal(l)) => {
          assert_true(l.get(0) == @value.Value::IntVal(1L))
          assert_true(l.get(3) == @value.Value::IntVal(4L))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.reverse reverses elements in place" {
  match exec_b("lst = [1, 2, 3]\nlst.reverse()") {
    Ok(m) =>
      match g(m, "lst") {
        Some(@value.Value::ListVal(l)) => {
          assert_true(l.get(0) == @value.Value::IntVal(3L))
          assert_true(l.get(2) == @value.Value::IntVal(1L))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.index returns position of first matching element" {
  match exec_b("i = [10, 20, 30].index(20)") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::IntVal(1L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.count returns number of occurrences" {
  match exec_b("n = [1, 2, 1, 3, 1].count(1)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: list.insert places element at given index" {
  match exec_b("lst = [1, 3]\nlst.insert(1, 2)") {
    Ok(m) =>
      match g(m, "lst") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(1) == @value.Value::IntVal(2L))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- Dict methods ---

///|
test "exec_file: dict.get returns value for existing key" {
  match exec_b("v = {\"x\": 1}.get(\"x\")") {
    Ok(m) => assert_true(g(m, "v") == Some(@value.Value::IntVal(1L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.get returns None when key is absent" {
  match exec_b("v = {}.get(\"x\")") {
    Ok(m) => assert_true(g(m, "v") == Some(@value.Value::NoneVal))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.get returns default when key is absent and default provided" {
  match exec_b("v = {}.get(\"x\", 42)") {
    Ok(m) => assert_true(g(m, "v") == Some(@value.Value::IntVal(42L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.keys returns list of keys in insertion order" {
  match exec_b("ks = {\"a\": 1, \"b\": 2}.keys()") {
    Ok(m) =>
      match g(m, "ks") {
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 2)
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 2)
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 1)
          assert_true(l.get(0) is @value.Value::TupleVal(_))
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
      assert_true(g(m, "v") == Some(@value.Value::IntVal(99L)))
      match g(m, "d") {
        Some(@value.Value::DictVal(d)) => assert_eq(d.length(), 0)
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
        Some(@value.Value::DictVal(d)) => assert_eq(d.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.setdefault inserts key with default when absent" {
  match exec_b("d = {}\nv = d.setdefault(\"x\", 42)") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::IntVal(42L)))
      match g(m, "d") {
        Some(@value.Value::DictVal(d)) => assert_eq(d.length(), 1)
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "HELLO")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.startswith returns true when string starts with prefix" {
  match exec_b("r = \"hello\".startswith(\"he\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.endswith returns true when string ends with suffix" {
  match exec_b("r = \"hello\".endswith(\"lo\")") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.find returns index of first occurrence" {
  match exec_b("i = \"hello world\".find(\"world\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::IntVal(6L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.find returns -1 when substring is absent" {
  match exec_b("i = \"hello\".find(\"xyz\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::IntVal(-1L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.replace substitutes all occurrences" {
  match exec_b("s = \"aabbaa\".replace(\"aa\", \"x\")") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "xbbx")
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 3)
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "a, b, c")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.count returns number of non-overlapping occurrences" {
  match exec_b("n = \"abcabc\".count(\"ab\")") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(2L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.capitalize uppercases first character and lowercases rest" {
  match exec_b("s = \"hELLO\".capitalize()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "Hello")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.index returns position when substring is found" {
  match exec_b("i = \"hello world\".index(\"world\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::IntVal(6L)))
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
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.rfind returns -1 when substring is absent" {
  match exec_b("i = \"hello\".rfind(\"xyz\")") {
    Ok(m) => assert_true(g(m, "i") == Some(@value.Value::IntVal(-1L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns true for alphabetic string" {
  match exec_b("r = \"hello\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalpha returns false when string contains digit" {
  match exec_b("r = \"hello1\".isalpha()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isdigit returns true for digit-only string" {
  match exec_b("r = \"123\".isdigit()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isalnum returns true for alphanumeric string" {
  match exec_b("r = \"abc123\".isalnum()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.islower returns true when all cased chars are lowercase" {
  match exec_b("r = \"hello\".islower()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isupper returns true when all cased chars are uppercase" {
  match exec_b("r = \"HELLO\".isupper()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.isspace returns true for whitespace-only string" {
  match exec_b("r = \"   \".isspace()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.title converts to titlecase" {
  match exec_b("s = \"hello world\".title()") {
    Ok(m) =>
      match g(m, "s") {
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "Hello World")
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
        Some(@value.Value::TupleVal(t)) => {
          assert_eq(t.length(), 3)
          match t[0] {
            @value.Value::StrVal(s) => assert_eq(s.raw, "hello")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "llo")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "hel")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.splitlines splits at newline characters" {
  match exec_b("r = \"a\\nb\\nc\".splitlines()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.elems iterates bytes as single-byte strings" {
  match exec_b("r = \"abc\".elems()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: string.elem_ords iterates bytes as integers" {
  match exec_b("r = \"ABC\".elem_ords()") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(0) == @value.Value::IntVal(65L))
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
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(1L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.discard removes element without error when absent" {
  match exec_b("s = {1, 2}\ns.discard(9)\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(2L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.remove removes existing element" {
  match exec_b("s = {1, 2}\ns.remove(1)\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(1L)))
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
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(0L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.pop removes and returns an arbitrary element" {
  match exec_b("s = {42}\nv = s.pop()") {
    Ok(m) => {
      assert_true(g(m, "v") == Some(@value.Value::IntVal(42L)))
      match g(m, "s") {
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 0)
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 3)
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 2)
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 1)
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 2)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.issubset returns true when all elements are in other" {
  match exec_b("r = {1, 2}.issubset({1, 2, 3})") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.issubset returns false when self has element not in other" {
  match exec_b("r = {1, 4}.issubset({1, 2, 3})") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(false)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.issuperset returns true when self contains all of other" {
  match exec_b("r = {1, 2, 3}.issuperset({1, 2})") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::BoolVal(true)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: set.update adds all elements from other into self" {
  match exec_b("s = {1, 2}\ns.update({2, 3, 4})\nn = len(s)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(4L)))
    Err(e) => fail(e.to_string())
  }
}

// --- dict.clear and dict.popitem ---

///|
test "exec_file: dict.clear removes all entries" {
  match exec_b("d = {\"a\": 1, \"b\": 2}\nd.clear()\nn = len(d)") {
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(0L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: dict.popitem removes and returns an item as tuple" {
  match exec_b("d = {\"x\": 1}\nt = d.popitem()\nn = len(d)") {
    Ok(m) => {
      assert_true(g(m, "n") == Some(@value.Value::IntVal(0L)))
      assert_true(g(m, "t") is Some(@value.Value::TupleVal(_)))
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "A")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.byte_len(), 1)
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
    Ok(m) => assert_true(g(m, "n") == Some(@value.Value::IntVal(65L)))
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

// --- Lambda ---

///|
test "exec_file: lambda produces a callable value" {
  match exec_b("f = lambda x: x + 1\nr = f(41)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::IntVal(42L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: lambda with no parameters returns constant" {
  match exec_b("f = lambda: 99\nr = f()") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::IntVal(99L)))
    Err(e) => fail(e.to_string())
  }
}

// --- Comprehensions ---

///|
test "exec_file: list comprehension transforms and filters elements" {
  match exec_b("r = [x * 2 for x in [1, 2, 3, 4] if x > 2]") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 2)
          assert_true(l.get(0) == @value.Value::IntVal(6L))
          assert_true(l.get(1) == @value.Value::IntVal(8L))
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
        Some(@value.Value::DictVal(d)) => {
          assert_eq(d.length(), 3)
          let key = @value.Value::IntVal(2L)
          assert_true(d.get(key) == Ok(Some(@value.Value::IntVal(4L))))
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
        Some(@value.Value::SetVal(s)) => assert_eq(s.length(), 3)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- Function features ---

///|
test "exec_file: function with default parameter uses default when omitted" {
  match exec_b("def f(x, y=10):\n  return x + y\nr = f(5)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::IntVal(15L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: function with star args collects extra positional arguments" {
  match exec_b("def f(*args):\n  return len(args)\nr = f(1, 2, 3)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::IntVal(3L)))
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: function with keyword args collects extra keyword arguments" {
  match exec_b("def f(**kwargs):\n  return len(kwargs)\nr = f(x=1, y=2)") {
    Ok(m) => assert_true(g(m, "r") == Some(@value.Value::IntVal(2L)))
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
    Options::default(),
  )
  assert_true(result is Err(_))
}

// --- bytes constructor ---

///|
test "exec_file: bytes constructor accepts a bytes literal" {
  match exec_b("r = bytes(b\"ABC\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::BytesVal(b)) => assert_eq(b.length(), 3)
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
        Some(@value.Value::BytesVal(b)) => {
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(0) == @value.Value::IntVal(65L))
          assert_true(l.get(1) == @value.Value::IntVal(66L))
          assert_true(l.get(2) == @value.Value::IntVal(67L))
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 0)
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "a and b")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "hello world")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "\"hi\"")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "{ x }")
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

// --- sorted with key= and reverse= ---

///|
test "exec_file: sorted with key= sorts by key function result" {
  match exec_b("r = sorted([\"bb\", \"a\", \"ccc\"], key=len)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          match l.get(0) {
            @value.Value::StrVal(s) => assert_eq(s.raw, "a")
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(0) == @value.Value::IntVal(3L))
          assert_true(l.get(2) == @value.Value::IntVal(1L))
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- min/max with key= ---

///|
test "exec_file: min with key= returns element with smallest key" {
  match exec_b("r = min([\"bb\", \"a\", \"ccc\"], key=len)") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "a")
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
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "ccc")
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

// --- print with sep= and end= ---

///|
test "exec_file: print with sep= uses custom separator" {
  let captured = Array::new()
  let t = Thread::with_print("<test>", fn(s) { captured.push(s) })
  ignore(
    exec_file(t, "<test>", "print(1, 2, 3, sep=\"-\")", Options::default()),
  )
  assert_true(captured.length() > 0 && captured[0] == "1-2-3")
}

///|
test "exec_file: print with sep= and no args outputs empty string" {
  let captured = Array::new()
  let t = Thread::with_print("<test>", fn(s) { captured.push(s) })
  ignore(exec_file(t, "<test>", "print(sep=\",\")", Options::default()))
  assert_true(captured.length() > 0 && captured[0] == "")
}

// --- dir() ---

///|
test "exec_file: dir on string returns sorted method names" {
  match exec_b("r = dir(\"hello\")") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::ListVal(l)) => {
          assert_true(l.length() > 0)
          assert_true(l.get(0) is @value.Value::StrVal(_))
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
        Some(@value.Value::ListVal(l)) => assert_true(l.length() > 0)
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 0)
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          match l.get(0) {
            @value.Value::StrVal(s) => assert_eq(s.raw, "a")
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          match l.get(0) {
            @value.Value::StrVal(s) => assert_eq(s.raw, "a,b")
            _ => assert_true(false)
          }
          match l.get(2) {
            @value.Value::StrVal(s) => assert_eq(s.raw, "d")
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          match l.get(0) {
            @value.Value::StrVal(s) => assert_eq(s.raw, "a")
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(l.get(0) == @value.Value::IntVal(65L))
          assert_true(l.get(1) == @value.Value::IntVal(66L))
          assert_true(l.get(2) == @value.Value::IntVal(67L))
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: module() creates a named module with attributes" {
  match exec_b("m = module(\"mymod\", x=1, y=2)") {
    Ok(m) =>
      match g(m, "m") {
        Some(@value.Value::ModuleVal(mod)) => {
          assert_eq(@value.type_name(@value.Value::ModuleVal(mod)), "module")
          assert_eq(mod.name, "mymod")
        }
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: module attribute access via dot returns correct value" {
  match exec_b("m = module(\"mymod\", x=42)\nr = m.x") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::IntVal(n)) => assert_eq(n, 42L)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}

///|
test "exec_file: module type_name is module" {
  match exec_b("r = type(module(\"m\"))") {
    Ok(m) =>
      match g(m, "r") {
        Some(@value.Value::StrVal(s)) => assert_eq(s.raw, "module")
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(
            l.get(0) == @value.Value::StrVal(@value.StarlarkString::new("a")),
          )
          assert_true(
            l.get(1) == @value.Value::StrVal(@value.StarlarkString::new("b")),
          )
          assert_true(
            l.get(2) == @value.Value::StrVal(@value.StarlarkString::new("c")),
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
        Some(@value.Value::ListVal(l)) => {
          assert_eq(l.length(), 3)
          assert_true(
            l.get(0) == @value.Value::StrVal(@value.StarlarkString::new("a\n")),
          )
          assert_true(
            l.get(1) == @value.Value::StrVal(@value.StarlarkString::new("b\n")),
          )
          assert_true(
            l.get(2) == @value.Value::StrVal(@value.StarlarkString::new("c")),
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
        Some(@value.Value::ListVal(l)) => assert_eq(l.length(), 0)
        _ => assert_true(false)
      }
    Err(e) => fail(e.to_string())
  }
}
