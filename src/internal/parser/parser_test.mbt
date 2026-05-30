// Parser tests — TDD Red phase.

///|
fn parse_e(src : String) -> @syntax.Expr {
  match @parser.parse_expr("test.star", src) {
    Ok(e) => e
    Err(e) => abort("parse error: \{e.to_string()}")
  }
}

///|
fn parse_f(src : String) -> @syntax.File {
  match @parser.parse_file("test.star", src) {
    Ok(f) => f
    Err(e) => abort("parse error: \{e.to_string()}")
  }
}

// --- Literal expressions ---

///|
test "integer literal is parsed as LitInt" {
  match parse_e("42") {
    ELiteral(LitInt(42N), _) => ()
    _ => fail("expected LitInt(42)")
  }
}

///|
test "zero integer literal" {
  match parse_e("0") {
    ELiteral(LitInt(0N), _) => ()
    _ => fail("expected LitInt(0)")
  }
}

///|
test "hex integer literal" {
  match parse_e("0xFF") {
    ELiteral(LitInt(255N), _) => ()
    _ => fail("expected LitInt(255)")
  }
}

///|
test "float literal is parsed as LitFloat" {
  match parse_e("1.5") {
    ELiteral(LitFloat(f), _) => assert_eq(f, 1.5)
    _ => fail("expected LitFloat(1.5)")
  }
}

///|
test "string literal is parsed as LitString" {
  match parse_e("\"hello\"") {
    ELiteral(LitString("hello"), _) => ()
    _ => fail("expected LitString(\"hello\")")
  }
}

///|
test "None literal is parsed as LitNone" {
  match parse_e("None") {
    ELiteral(LitNone, _) => ()
    _ => fail("expected LitNone")
  }
}

///|
test "True literal is parsed as LitBool(true)" {
  match parse_e("True") {
    ELiteral(LitBool(true), _) => ()
    _ => fail("expected LitBool(true)")
  }
}

///|
test "False literal is parsed as LitBool(false)" {
  match parse_e("False") {
    ELiteral(LitBool(false), _) => ()
    _ => fail("expected LitBool(false)")
  }
}

///|
test "identifier is parsed as EIdent" {
  match parse_e("xyz") {
    EIdent("xyz", _) => ()
    _ => fail("expected EIdent(\"xyz\")")
  }
}

// --- Unary expressions ---

///|
test "unary minus on integer" {
  match parse_e("-1") {
    EUnary(OpMinus, ELiteral(LitInt(1N), _), _) => ()
    _ => fail("expected EUnary(OpMinus, LitInt(1))")
  }
}

///|
test "unary not on identifier" {
  match parse_e("not x") {
    EUnary(OpNot, EIdent("x", _), _) => ()
    _ => fail("expected EUnary(OpNot, EIdent(x))")
  }
}

///|
test "unary bitwise not" {
  match parse_e("~x") {
    EUnary(OpBitNot, EIdent("x", _), _) => ()
    _ => fail("expected EUnary(OpBitNot, EIdent(x))")
  }
}

// --- Binary expressions ---

///|
test "binary addition" {
  match parse_e("1 + 2") {
    EBinary(ELiteral(LitInt(1N), _), OpAdd, ELiteral(LitInt(2N), _), _) => ()
    _ => fail("expected 1 + 2")
  }
}

///|
test "multiplication has higher precedence than addition" {
  match parse_e("1 + 2 * 3") {
    EBinary(
      ELiteral(LitInt(1N), _),
      OpAdd,
      EBinary(ELiteral(LitInt(2N), _), OpMul, ELiteral(LitInt(3N), _), _),
      _
    ) => ()
    _ => fail("expected 1 + (2 * 3)")
  }
}

///|
test "floor division" {
  match parse_e("7 // 2") {
    EBinary(_, OpFloorDiv, _, _) => ()
    _ => fail("expected floor division")
  }
}

///|
test "power operator" {
  match parse_e("2 ** 10") {
    EBinary(ELiteral(LitInt(2N), _), OpPow, ELiteral(LitInt(10N), _), _) => ()
    _ => fail("expected 2 ** 10")
  }
}

///|
test "equality comparison" {
  match parse_e("x == y") {
    EBinary(EIdent("x", _), OpEq, EIdent("y", _), _) => ()
    _ => fail("expected x == y")
  }
}

///|
test "in operator" {
  match parse_e("x in lst") {
    EBinary(EIdent("x", _), OpIn, EIdent("lst", _), _) => ()
    _ => fail("expected x in lst")
  }
}

///|
test "not in operator" {
  match parse_e("x not in lst") {
    EBinary(EIdent("x", _), OpNotIn, EIdent("lst", _), _) => ()
    _ => fail("expected x not in lst")
  }
}

///|
test "boolean and" {
  match parse_e("a and b") {
    EBinary(EIdent("a", _), OpAnd, EIdent("b", _), _) => ()
    _ => fail("expected a and b")
  }
}

///|
test "boolean or" {
  match parse_e("a or b") {
    EBinary(EIdent("a", _), OpOr, EIdent("b", _), _) => ()
    _ => fail("expected a or b")
  }
}

// --- Conditional expression ---

///|
test "conditional expression x if c else y" {
  match parse_e("1 if True else 0") {
    ECond(
      ELiteral(LitInt(1N), _),
      ELiteral(LitBool(true), _),
      ELiteral(LitInt(0N), _),
      _
    ) => ()
    _ => fail("expected conditional expression")
  }
}

// --- Collection literals ---

///|
test "empty list literal" {
  match parse_e("[]") {
    EList(items, _) => assert_eq(items.length(), 0)
    _ => fail("expected empty list")
  }
}

///|
test "list with elements" {
  match parse_e("[1, 2, 3]") {
    EList(items, _) => assert_eq(items.length(), 3)
    _ => fail("expected list with 3 elements")
  }
}

///|
test "empty tuple from parentheses" {
  match parse_e("()") {
    ETuple(items, _) => assert_eq(items.length(), 0)
    _ => fail("expected empty tuple")
  }
}

///|
test "single element tuple requires trailing comma" {
  match parse_e("(1,)") {
    ETuple(items, _) => assert_eq(items.length(), 1)
    _ => fail("expected singleton tuple")
  }
}

///|
test "multi-element tuple with parens" {
  match parse_e("(1, 2)") {
    ETuple(items, _) => assert_eq(items.length(), 2)
    _ => fail("expected 2-element tuple")
  }
}

///|
test "empty dict literal" {
  match parse_e("{}") {
    EDict(pairs, _) => assert_eq(pairs.length(), 0)
    _ => fail("expected empty dict")
  }
}

///|
test "dict with entries" {
  match parse_e("{\"a\": 1, \"b\": 2}") {
    EDict(pairs, _) => assert_eq(pairs.length(), 2)
    _ => fail("expected dict with 2 entries")
  }
}

///|
test "set literal" {
  match parse_e("{1, 2, 3}") {
    ESet(items, _) => assert_eq(items.length(), 3)
    _ => fail("expected set with 3 elements")
  }
}

// --- Call, dot, index, slice ---

///|
test "function call with no args" {
  match parse_e("f()") {
    ECall(EIdent("f", _), args, _) => assert_eq(args.length(), 0)
    _ => fail("expected f()")
  }
}

///|
test "function call with positional args" {
  match parse_e("f(1, 2)") {
    ECall(EIdent("f", _), args, _) => assert_eq(args.length(), 2)
    _ => fail("expected f(1, 2)")
  }
}

///|
test "function call with keyword arg" {
  match parse_e("f(x=1)") {
    ECall(EIdent("f", _), args, _) => {
      assert_eq(args.length(), 1)
      match args[0] {
        ArgKw("x", ELiteral(LitInt(1N), _), _) => ()
        _ => fail("expected keyword arg x=1")
      }
    }
    _ => fail("expected f(x=1)")
  }
}

///|
test "attribute access" {
  match parse_e("obj.attr") {
    EDot(EIdent("obj", _), "attr", _) => ()
    _ => fail("expected obj.attr")
  }
}

///|
test "index access" {
  match parse_e("lst[0]") {
    EIndex(EIdent("lst", _), ELiteral(LitInt(0N), _), _) => ()
    _ => fail("expected lst[0]")
  }
}

///|
test "slice with start and end" {
  match parse_e("lst[1:3]") {
    ESlice(
      EIdent("lst", _),
      Some(ELiteral(LitInt(1N), _)),
      Some(ELiteral(LitInt(3N), _)),
      None,
      _
    ) => ()
    _ => fail("expected lst[1:3]")
  }
}

///|
test "full slice with step" {
  match parse_e("lst[::2]") {
    ESlice(EIdent("lst", _), None, None, Some(ELiteral(LitInt(2N), _)), _) => ()
    _ => fail("expected lst[::2]")
  }
}

// --- Lambda ---

///|
test "lambda with no params" {
  match parse_e("lambda: 42") {
    ELambda(params, ELiteral(LitInt(42N), _), _) =>
      assert_eq(params.length(), 0)
    _ => fail("expected lambda: 42")
  }
}

///|
test "lambda with one param" {
  match parse_e("lambda x: x") {
    ELambda(params, EIdent("x", _), _) => {
      assert_eq(params.length(), 1)
      match params[0] {
        ParamIdent("x", _) => ()
        _ => fail("expected param x")
      }
    }
    _ => fail("expected lambda x: x")
  }
}

// --- List comprehension ---

///|
test "list comprehension" {
  match parse_e("[x for x in lst]") {
    EListComp(EIdent("x", _), clauses, _) => {
      assert_eq(clauses.length(), 1)
      match clauses[0] {
        ClauseFor(EIdent("x", _), EIdent("lst", _), _) => ()
        _ => fail("expected for x in lst clause")
      }
    }
    _ => fail("expected list comprehension")
  }
}

///|
test "list comprehension with if filter" {
  match parse_e("[x for x in lst if x > 0]") {
    EListComp(EIdent("x", _), clauses, _) => assert_eq(clauses.length(), 2)
    _ => fail("expected list comprehension with filter")
  }
}

// --- Simple statements ---

///|
test "empty file has no stmts" {
  let f = parse_f("")
  assert_eq(f.stmts().length(), 0)
}

///|
test "pass statement" {
  let f = parse_f("pass\n")
  assert_eq(f.stmts().length(), 1)
  match f.stmts()[0] {
    SPass(_) => ()
    _ => fail("expected SPass")
  }
}

///|
test "break statement" {
  let f = parse_f("break\n")
  match f.stmts()[0] {
    SBreak(_) => ()
    _ => fail("expected SBreak")
  }
}

///|
test "continue statement" {
  let f = parse_f("continue\n")
  match f.stmts()[0] {
    SContinue(_) => ()
    _ => fail("expected SContinue")
  }
}

///|
test "return with value" {
  let f = parse_f("return 42\n")
  match f.stmts()[0] {
    SReturn(Some(ELiteral(LitInt(42N), _)), _) => ()
    _ => fail("expected SReturn(42)")
  }
}

///|
test "return without value" {
  let f = parse_f("return\n")
  match f.stmts()[0] {
    SReturn(None, _) => ()
    _ => fail("expected SReturn(None)")
  }
}

///|
test "simple assignment" {
  let f = parse_f("x = 1\n")
  match f.stmts()[0] {
    SAssign(EIdent("x", _), ELiteral(LitInt(1N), _), _) => ()
    _ => fail("expected x = 1")
  }
}

///|
test "augmented assignment plus-equals" {
  let f = parse_f("x += 1\n")
  match f.stmts()[0] {
    SAugAssign(EIdent("x", _), AugAdd, ELiteral(LitInt(1N), _), _) => ()
    _ => fail("expected x += 1")
  }
}

///|
test "expression statement" {
  let f = parse_f("f()\n")
  match f.stmts()[0] {
    SExpr(ECall(EIdent("f", _), _, _)) => ()
    _ => fail("expected SExpr(f())")
  }
}

// --- Compound statements ---

///|
test "if statement with single-line body" {
  let f = parse_f("if x:\n  pass\n")
  match f.stmts()[0] {
    SIf(EIdent("x", _), body, else_body, _) => {
      assert_eq(body.length(), 1)
      assert_eq(else_body.length(), 0)
    }
    _ => fail("expected if statement")
  }
}

///|
test "if else statement" {
  let f = parse_f("if x:\n  pass\nelse:\n  pass\n")
  match f.stmts()[0] {
    SIf(_, true_body, false_body, _) => {
      assert_eq(true_body.length(), 1)
      assert_eq(false_body.length(), 1)
    }
    _ => fail("expected if-else")
  }
}

///|
test "for loop" {
  let f = parse_f("for x in lst:\n  pass\n")
  match f.stmts()[0] {
    SFor(EIdent("x", _), EIdent("lst", _), body, _) =>
      assert_eq(body.length(), 1)
    _ => fail("expected for loop")
  }
}

///|
test "while loop" {
  let f = parse_f("while True:\n  pass\n")
  match f.stmts()[0] {
    SWhile(ELiteral(LitBool(true), _), body, _) => assert_eq(body.length(), 1)
    _ => fail("expected while loop")
  }
}

///|
test "function definition with no params" {
  let f = parse_f("def f():\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, body, _) => {
      assert_eq(params.length(), 0)
      assert_eq(body.length(), 1)
    }
    _ => fail("expected def f()")
  }
}

///|
test "function definition with param and default" {
  let f = parse_f("def f(x, y=1):\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, _, _) => {
      assert_eq(params.length(), 2)
      match params[0] {
        ParamIdent("x", _) => ()
        _ => fail("expected param x")
      }
      match params[1] {
        ParamDefault("y", ELiteral(LitInt(1N), _), _) => ()
        _ => fail("expected param y=1")
      }
    }
    _ => fail("expected def with params")
  }
}

///|
test "function definition with star args" {
  let f = parse_f("def f(*args):\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, _, _) => {
      assert_eq(params.length(), 1)
      match params[0] {
        ParamStarIdent("args", _) => ()
        _ => fail("expected *args param")
      }
    }
    _ => fail("expected def f(*args)")
  }
}

///|
test "function definition with kwargs" {
  let f = parse_f("def f(**kwargs):\n  pass\n")
  match f.stmts()[0] {
    SDef("f", params, _, _) =>
      match params[0] {
        ParamKwIdent("kwargs", _) => ()
        _ => fail("expected **kwargs param")
      }
    _ => fail("expected def f(**kwargs)")
  }
}

///|
test "load statement with single binding" {
  let f = parse_f("load(\"mod.star\", \"sym\")\n")
  match f.stmts()[0] {
    SLoad("mod.star", bindings, _) => {
      assert_eq(bindings.length(), 1)
      let (bind_name, original) = bindings[0]
      assert_eq(bind_name, "sym")
      assert_eq(original, "sym")
    }
    _ => fail("expected load statement")
  }
}

///|
test "load statement with aliased binding" {
  let f = parse_f("load(\"mod.star\", alias=\"sym\")\n")
  match f.stmts()[0] {
    SLoad("mod.star", bindings, _) => {
      let (bind_name, original) = bindings[0]
      assert_eq(bind_name, "alias")
      assert_eq(original, "sym")
    }
    _ => fail("expected aliased load")
  }
}

// --- Position tracking ---

///|
test "integer literal has position line 1 col 1" {
  match parse_e("42") {
    ELiteral(_, pos) => {
      assert_eq(pos.line(), 1)
      assert_eq(pos.col(), 1)
    }
    _ => fail("expected literal")
  }
}

// --- Error cases: Python constructs not allowed in Starlark ---

///|
test "import statement is rejected" {
  match @parser.parse_file("test.star", "import os\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for import statement")
  }
}

///|
test "global statement is rejected" {
  match @parser.parse_file("test.star", "global x\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for global statement")
  }
}

///|
test "raise statement is rejected" {
  match @parser.parse_file("test.star", "raise Exception()\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for raise statement")
  }
}

///|
test "class definition is rejected" {
  match @parser.parse_file("test.star", "class Foo:\n  pass\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for class definition")
  }
}

///|
test "del statement is rejected" {
  match @parser.parse_file("test.star", "del x\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for del statement")
  }
}

///|
test "print-as-statement syntax is rejected" {
  match @parser.parse_file("test.star", "print \"hello\"\n") {
    Err(_) => ()
    Ok(_) => fail("expected syntax error for print-as-statement")
  }
}

// --- Non-associative comparison operators ---

///|
fn parse_e_err(src : String) -> String {
  match @parser.parse_expr("test.star", src) {
    Err(e) => e.msg()
    Ok(_) => ""
  }
}

///|
test "chained == == is rejected as non-associative" {
  let msg = parse_e_err("0 == 1 == 2")
  if !msg.contains("== does not associate with ==") {
    fail("expected non-associative error, got: \{msg}")
  }
}

///|
test "chained <= < is rejected as non-associative" {
  let msg = parse_e_err("0 <= i < n")
  if !msg.contains("<= does not associate with <") {
    fail("expected non-associative error, got: \{msg}")
  }
}

///|
test "chained in not-in is rejected as non-associative" {
  let msg = parse_e_err("a in b not in c")
  if !msg.contains("in does not associate with not in") {
    fail("expected non-associative error, got: \{msg}")
  }
}

///|
test "parenthesized comparisons are allowed" {
  match @parser.parse_expr("test.star", "(0 == 1) == 2") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
  match @parser.parse_expr("test.star", "0 == (1 == 2)") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.msg()}")
  }
}

///|
fn parse_f_err(src : String) -> String {
  match @parser.parse_file("test.star", src) {
    Err(e) => e.msg()
    Ok(_) => ""
  }
}

// --- Python constructs not supported in Starlark ---

///|
test "is operator is rejected" {
  let msg = parse_e_err("x is y")
  if !msg.contains("'is' operator is not allowed") {
    fail("expected 'is' rejection, got: \{msg}")
  }
}

///|
test "is not operator is rejected" {
  let msg = parse_e_err("x is not y")
  if !msg.contains("'is' operator is not allowed") {
    fail("expected 'is not' rejection, got: \{msg}")
  }
}

///|
test "type annotation in function parameter is rejected" {
  let msg = parse_f_err("def f(x: int): pass\n")
  if !msg.contains("type annotations are not allowed") {
    fail("expected annotation rejection, got: \{msg}")
  }
}

///|
test "annotated assignment is rejected" {
  let msg = parse_f_err("x: int = 1\n")
  if !msg.contains("type annotations are not allowed") {
    fail("expected annotation rejection, got: \{msg}")
  }
}

///|
test "starred target in tuple unpacking LHS is rejected" {
  let msg = parse_f_err("a, *b = [1, 2]\n")
  if !msg.contains("'*' is not allowed as assignment target") {
    fail("expected starred target rejection, got: \{msg}")
  }
}

///|
test "walrus operator := is rejected" {
  let msg = parse_f_err("x := 5\n")
  if !msg.contains("walrus operator") && !msg.contains(":=") {
    fail("expected walrus rejection, got: \{msg}")
  }
}

// --- AST walker ---

///|
test "walk: visits all idents in assignment" {
  let file = parse_f("x = 1\n")
  let idents : Array[String] = []
  @syntax.walk_file(file, fn(node) {
    match node {
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) =>
        idents.push(name)
      _ => ()
    }
    true
  })
  if !idents.contains("x") {
    fail("expected ident 'x', got: [\{idents.join(", ")}]")
  }
}

///|
test "walk: visitor returning false skips children" {
  let file = parse_f("def f(x):\n  y = x + 1\n")
  let visited : Array[String] = []
  @syntax.walk_file(file, fn(node) {
    match node {
      Some(@syntax.Node::NStmt(@syntax.Stmt::SDef(name, _, _, _))) => {
        visited.push("def:\{name}")
        false
      }
      Some(@syntax.Node::NExpr(@syntax.Expr::EIdent(name, _))) => {
        visited.push("ident:\{name}")
        true
      }
      _ => true
    }
  })
  if visited.contains("ident:x") || visited.contains("ident:y") {
    fail("expected no traversal inside def body, got: [\{visited.join(", ")}]")
  }
}

///|
test "walk: visits all clauses in comprehension" {
  let expr = parse_e("[x for x in xs if x > 0]")
  let kinds : Array[String] = []
  @syntax.walk_expr(expr, fn(node) {
    match node {
      Some(@syntax.Node::NCompClause(@syntax.CompClause::ClauseFor(_, _, _))) =>
        kinds.push("for")
      Some(@syntax.Node::NCompClause(@syntax.CompClause::ClauseIf(_, _))) =>
        kinds.push("if")
      _ => ()
    }
    true
  })
  assert_eq(kinds.join(","), "for,if")
}

// --- Keyword literals: None, True, False must not be identifiers ---

///|
test "parser: None cannot be a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(None): pass\n")
  assert_true(result is Err(_))
}

///|
test "parser: True cannot be a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(True): pass\n")
  assert_true(result is Err(_))
}

///|
test "parser: False cannot be a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(False): pass\n")
  assert_true(result is Err(_))
}

///|
test "parser: None with default cannot be a function parameter name" {
  let result = @parser.parse_file("test.star", "def f(None=0): pass\n")
  assert_true(result is Err(_))
}

///|
test "parser: None True False still parse as literal expressions" {
  match parse_e("None") {
    ELiteral(LitNone, _) => ()
    _ => fail("expected LitNone")
  }
  match parse_e("True") {
    ELiteral(LitBool(true), _) => ()
    _ => fail("expected LitBool(true)")
  }
  match parse_e("False") {
    ELiteral(LitBool(false), _) => ()
    _ => fail("expected LitBool(false)")
  }
}

///|
test "load with zero imported symbols is rejected" {
  match @parser.parse_file("test.star", "load(\"m\")\n") {
    Err(e) => assert_true(e.msg().contains("must import at least 1 symbol"))
    Ok(_) => fail("expected error for load with no symbols")
  }
}

///|
test "load with at least one symbol parses" {
  match @parser.parse_file("test.star", "load(\"m\", \"a\")\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.to_string()}")
  }
}

///|
test "unparenthesized tuple with trailing comma is rejected" {
  match @parser.parse_file("test.star", "x, = 1,\n") {
    Err(e) =>
      assert_true(e.msg().contains("unparenthesized tuple with trailing comma"))
    Ok(_) => fail("expected error for trailing comma")
  }
}

///|
test "parenthesized singleton tuple with trailing comma is allowed" {
  match @parser.parse_file("test.star", "x = (1,)\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.to_string()}")
  }
}

///|
test "for-loop target with binary operator is rejected" {
  match @parser.parse_file("test.star", "for a + b in xs:\n  pass\n") {
    Err(_) => ()
    Ok(_) => fail("expected error for non-primary for-target")
  }
}

///|
test "comprehension target with binary operator is rejected" {
  match @parser.parse_expr("test.star", "[x for a + b in xs]") {
    Err(_) => ()
    Ok(_) => fail("expected error for non-primary comprehension target")
  }
}

///|
test "for-loop with index/attribute targets parses" {
  match @parser.parse_file("test.star", "for a[0], b.c in xs:\n  pass\n") {
    Ok(_) => ()
    Err(e) => fail("unexpected error: \{e.to_string()}")
  }
}

// --- Parser error message parity ---

///|
test "conditional expression without else clause produces correct message" {
  match @parser.parse_expr("test.star", "x if y") {
    Err(e) =>
      assert_true(
        e.msg().contains("conditional expression without else clause"),
      )
    Ok(_) => fail("expected error for conditional without else")
  }
}

///|
test "load unquoted original name produces correct message" {
  match @parser.parse_file("test.star", "load(\"m\", x=originalname)\n") {
    Err(e) =>
      assert_true(
        e.msg().contains("original name of loaded symbol must be quoted"),
      )
    Ok(_) => fail("expected error for unquoted original name")
  }
}
